#!/bin/bash

# New-API Helm Chart Status Check Script
# This script provides comprehensive status information about your New-API deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="new-api"
RELEASE_NAME="new-api"
SHOW_LOGS=false
SHOW_EVENTS=false
SHOW_METRICS=false
FOLLOW_LOGS=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAMESPACE       Kubernetes namespace (default: new-api)
    -r, --release RELEASE_NAME      Helm release name (default: new-api)
    -l, --logs                      Show recent logs
    -f, --follow                    Follow logs (implies --logs)
    -e, --events                    Show recent events
    -m, --metrics                   Show resource metrics (requires metrics-server)
    -a, --all                       Show all information (logs, events, metrics)
    -h, --help                      Show this help message

Examples:
    # Basic status check
    $0

    # Show status with logs
    $0 --logs

    # Show all information
    $0 --all

    # Follow logs in real-time
    $0 --follow

    # Check specific namespace
    $0 -n production --all

EOF
}

# Function to check prerequisites
check_prerequisites() {
    if ! command -v helm &> /dev/null; then
        print_error "Helm 未安装"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到 Kubernetes 集群"
        exit 1
    fi
}

# Function to check if release exists
check_release_exists() {
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_error "在命名空间 $NAMESPACE 中未找到 release $RELEASE_NAME"
        exit 1
    fi
}

# Function to show helm release status
show_helm_status() {
    print_header "Helm Release 状态"
    
    print_info "Release 信息："
    helm list -n "$NAMESPACE" | grep "$RELEASE_NAME"
    
    echo
    print_info "Release 详细状态："
    helm status "$RELEASE_NAME" -n "$NAMESPACE"
    
    echo
    print_info "Release 历史："
    helm history "$RELEASE_NAME" -n "$NAMESPACE"
}

# Function to show pod status
show_pod_status() {
    print_header "Pod 状态"
    
    local pods
    pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o wide)
    
    if [ -n "$pods" ]; then
        echo "$pods"
        
        echo
        print_info "Pod 详细状态："
        kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o custom-columns="NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,AGE:.metadata.creationTimestamp"
    else
        print_warning "未找到相关的 Pod"
    fi
}

# Function to show service status
show_service_status() {
    print_header "Service 状态"
    
    local services
    services=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o wide)
    
    if [ -n "$services" ]; then
        echo "$services"
    else
        print_warning "未找到相关的 Service"
    fi
}

# Function to show ingress status
show_ingress_status() {
    print_header "Ingress 状态"
    
    local ingresses
    ingresses=$(kubectl get ingress -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o wide 2>/dev/null || true)
    
    if [ -n "$ingresses" ]; then
        echo "$ingresses"
    else
        print_info "未配置 Ingress 或未找到相关的 Ingress"
    fi
}

# Function to show persistent volume status
show_pv_status() {
    print_header "存储状态"
    
    local pvcs
    pvcs=$(kubectl get pvc -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o wide 2>/dev/null || true)
    
    if [ -n "$pvcs" ]; then
        print_info "Persistent Volume Claims："
        echo "$pvcs"
    else
        print_info "未找到相关的 PVC"
    fi
}

# Function to show deployment status
show_deployment_status() {
    print_header "Deployment 状态"
    
    # Check master deployment
    if kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-master &> /dev/null; then
        print_info "Master Deployment："
        kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-master -o wide
        
        echo
        print_info "Master Deployment 详细状态："
        kubectl describe deployment -n "$NAMESPACE" "$RELEASE_NAME"-master | grep -A 10 "Conditions:"
    fi
    
    # Check slave deployment
    if kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-slave &> /dev/null; then
        echo
        print_info "Slave Deployment："
        kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-slave -o wide
        
        echo
        print_info "Slave Deployment 详细状态："
        kubectl describe deployment -n "$NAMESPACE" "$RELEASE_NAME"-slave | grep -A 10 "Conditions:"
    fi
}

# Function to show statefulset status
show_statefulset_status() {
    print_header "StatefulSet 状态"
    
    # Check MySQL statefulset
    if kubectl get statefulset -n "$NAMESPACE" "$RELEASE_NAME"-mysql &> /dev/null; then
        print_info "MySQL StatefulSet："
        kubectl get statefulset -n "$NAMESPACE" "$RELEASE_NAME"-mysql -o wide
    fi
    
    # Check Redis statefulset
    if kubectl get statefulset -n "$NAMESPACE" "$RELEASE_NAME"-redis &> /dev/null; then
        echo
        print_info "Redis StatefulSet："
        kubectl get statefulset -n "$NAMESPACE" "$RELEASE_NAME"-redis -o wide
    fi
}

# Function to show HPA status
show_hpa_status() {
    print_header "HPA 状态"
    
    local hpas
    hpas=$(kubectl get hpa -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o wide 2>/dev/null || true)
    
    if [ -n "$hpas" ]; then
        echo "$hpas"
    else
        print_info "未配置 HPA 或未找到相关的 HPA"
    fi
}

# Function to show recent events
show_events() {
    if [ "$SHOW_EVENTS" = true ]; then
        print_header "最近事件"
        
        kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | grep "$RELEASE_NAME" | tail -20 || print_info "未找到相关事件"
    fi
}

# Function to show logs
show_logs() {
    if [ "$SHOW_LOGS" = true ]; then
        print_header "应用日志"
        
        # Show master logs
        if kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-master &> /dev/null; then
            print_info "Master 节点日志 (最近 50 行)："
            if [ "$FOLLOW_LOGS" = true ]; then
                kubectl logs -f deployment/"$RELEASE_NAME"-master -n "$NAMESPACE" --tail=50
            else
                kubectl logs deployment/"$RELEASE_NAME"-master -n "$NAMESPACE" --tail=50
            fi
        fi
        
        # Show slave logs if not following
        if [ "$FOLLOW_LOGS" = false ] && kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-slave &> /dev/null; then
            echo
            print_info "Slave 节点日志 (最近 20 行)："
            kubectl logs deployment/"$RELEASE_NAME"-slave -n "$NAMESPACE" --tail=20
        fi
    fi
}

# Function to show resource metrics
show_metrics() {
    if [ "$SHOW_METRICS" = true ]; then
        print_header "资源使用情况"
        
        if kubectl top nodes &> /dev/null; then
            print_info "节点资源使用："
            kubectl top nodes
            
            echo
            print_info "Pod 资源使用："
            kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" 2>/dev/null || print_warning "无法获取 Pod 资源使用情况 (需要 metrics-server)"
        else
            print_warning "metrics-server 未安装，无法显示资源使用情况"
        fi
    fi
}

# Function to show connectivity test
show_connectivity_test() {
    print_header "连接性测试"
    
    # Test internal service connectivity
    if kubectl get svc -n "$NAMESPACE" "$RELEASE_NAME" &> /dev/null; then
        print_info "测试内部服务连接性..."
        
        # Create a temporary pod for testing
        kubectl run test-connectivity --image=curlimages/curl:latest --rm -i --restart=Never -n "$NAMESPACE" -- curl -s -o /dev/null -w "%{http_code}" "http://$RELEASE_NAME.$NAMESPACE.svc.cluster.local" 2>/dev/null && print_success "内部服务连接正常" || print_warning "内部服务连接测试失败"
    fi
}

# Function to show summary
show_summary() {
    print_header "状态摘要"
    
    local total_pods=0
    local ready_pods=0
    local running_pods=0
    
    # Count pods
    if kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" &> /dev/null; then
        total_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" --no-headers | wc -l)
        ready_pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" --no-headers | grep -c "Running" || echo "0")
        running_pods=$ready_pods
    fi
    
    echo "总 Pod 数量: $total_pods"
    echo "运行中 Pod: $running_pods"
    echo "就绪 Pod: $ready_pods"
    
    if [ "$total_pods" -eq "$ready_pods" ] && [ "$total_pods" -gt 0 ]; then
        print_success "所有 Pod 都在正常运行"
    elif [ "$ready_pods" -gt 0 ]; then
        print_warning "部分 Pod 未就绪"
    else
        print_error "没有 Pod 在运行"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -l|--logs)
            SHOW_LOGS=true
            shift
            ;;
        -f|--follow)
            SHOW_LOGS=true
            FOLLOW_LOGS=true
            shift
            ;;
        -e|--events)
            SHOW_EVENTS=true
            shift
            ;;
        -m|--metrics)
            SHOW_METRICS=true
            shift
            ;;
        -a|--all)
            SHOW_LOGS=true
            SHOW_EVENTS=true
            SHOW_METRICS=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "未知选项：$1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_info "检查 New-API 部署状态..."
    print_info "命名空间：$NAMESPACE"
    print_info "Release 名称：$RELEASE_NAME"
    
    check_prerequisites
    check_release_exists
    
    show_helm_status
    show_pod_status
    show_deployment_status
    show_statefulset_status
    show_service_status
    show_ingress_status
    show_pv_status
    show_hpa_status
    show_events
    show_metrics
    show_connectivity_test
    show_summary
    
    # Show logs last (especially if following)
    show_logs
}

# Run main function
main