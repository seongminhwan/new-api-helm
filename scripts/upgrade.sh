#!/bin/bash

# New-API Helm Chart Upgrade Script
# This script helps you safely upgrade the New-API Helm chart

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="new-api"
RELEASE_NAME="new-api"
CHART_PATH="."
VALUES_FILE=""
DRY_RUN=false
BACKUP_BEFORE_UPGRADE=true
WAIT_FOR_READY=true
TIMEOUT="600s"

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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -n, --namespace NAMESPACE       Kubernetes namespace (default: new-api)
    -r, --release RELEASE_NAME      Helm release name (default: new-api)
    -f, --values VALUES_FILE        Values file to use
    -c, --chart CHART_PATH          Path to chart (default: .)
    --no-backup                     Skip backup before upgrade
    --no-wait                       Don't wait for deployment to be ready
    --timeout TIMEOUT               Timeout for waiting (default: 600s)
    --dry-run                       Perform a dry run
    -h, --help                      Show this help message

Examples:
    # Basic upgrade
    $0

    # Upgrade with new values file
    $0 -f examples/values-production.yaml

    # Dry run upgrade
    $0 --dry-run

    # Upgrade without backup
    $0 --no-backup

    # Upgrade with custom timeout
    $0 --timeout 900s

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_info "检查前置条件..."
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm 未安装。请先安装 Helm。"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装。请先安装 kubectl。"
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到 Kubernetes 集群。请检查您的 kubeconfig。"
        exit 1
    fi
    
    print_success "前置条件检查通过"
}

# Function to check if release exists
check_release_exists() {
    print_info "检查 Helm release 是否存在..."
    
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_error "在命名空间 $NAMESPACE 中未找到 release $RELEASE_NAME"
        print_info "请先使用 install.sh 脚本安装应用"
        exit 1
    fi
    
    print_success "找到 release $RELEASE_NAME"
}

# Function to show current release info
show_current_release_info() {
    print_info "当前 release 信息："
    helm list -n "$NAMESPACE" | grep "$RELEASE_NAME"
    
    print_info "当前部署状态："
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME"
}

# Function to backup current release
backup_current_release() {
    if [ "$BACKUP_BEFORE_UPGRADE" = true ]; then
        print_info "创建升级前备份..."
        
        local backup_dir="upgrade-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        
        # Backup current helm values
        print_info "备份当前 Helm values..."
        helm get values "$RELEASE_NAME" -n "$NAMESPACE" > "$backup_dir/current-values.yaml"
        
        # Backup current manifest
        print_info "备份当前 manifest..."
        helm get manifest "$RELEASE_NAME" -n "$NAMESPACE" > "$backup_dir/current-manifest.yaml"
        
        # Backup application data if possible
        if kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-master &> /dev/null; then
            print_info "备份应用数据..."
            kubectl exec -n "$NAMESPACE" deployment/"$RELEASE_NAME"-master -- tar czf /tmp/pre-upgrade-backup.tar.gz /app/data /app/logs 2>/dev/null || print_warning "应用数据备份失败"
            kubectl cp "$NAMESPACE"/"$RELEASE_NAME"-master:/tmp/pre-upgrade-backup.tar.gz "$backup_dir/app-data-backup.tar.gz" 2>/dev/null || print_warning "应用数据备份复制失败"
        fi
        
        print_success "备份已创建在目录：$backup_dir"
        echo "$backup_dir" > .last-backup-dir
    fi
}

# Function to validate values file
validate_values_file() {
    if [ -n "$VALUES_FILE" ]; then
        if [ ! -f "$VALUES_FILE" ]; then
            print_error "Values 文件未找到：$VALUES_FILE"
            exit 1
        fi
        print_info "使用 values 文件：$VALUES_FILE"
    else
        print_info "使用默认 values"
    fi
}

# Function to perform upgrade
perform_upgrade() {
    print_info "开始升级 New-API Helm chart..."
    
    local helm_cmd="helm upgrade $RELEASE_NAME $CHART_PATH --namespace $NAMESPACE"
    
    if [ -n "$VALUES_FILE" ]; then
        helm_cmd="$helm_cmd --values $VALUES_FILE"
    fi
    
    if [ "$WAIT_FOR_READY" = true ]; then
        helm_cmd="$helm_cmd --wait --timeout $TIMEOUT"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        helm_cmd="$helm_cmd --dry-run"
        print_info "执行 dry run..."
    fi
    
    if eval "$helm_cmd"; then
        if [ "$DRY_RUN" = false ]; then
            print_success "New-API 升级成功！"
            print_info "Release 名称：$RELEASE_NAME"
            print_info "命名空间：$NAMESPACE"
            
            # Show status
            print_info "检查部署状态..."
            helm status "$RELEASE_NAME" -n "$NAMESPACE"
            
            # Show rollout status
            show_rollout_status
        else
            print_success "Dry run 完成成功！"
        fi
    else
        print_error "升级失败"
        show_rollback_instructions
        exit 1
    fi
}

# Function to show rollout status
show_rollout_status() {
    print_info "检查 rollout 状态..."
    
    # Check master deployment
    if kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-master &> /dev/null; then
        print_info "检查 master deployment 状态..."
        kubectl rollout status deployment/"$RELEASE_NAME"-master -n "$NAMESPACE" --timeout="$TIMEOUT"
    fi
    
    # Check slave deployment
    if kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME"-slave &> /dev/null; then
        print_info "检查 slave deployment 状态..."
        kubectl rollout status deployment/"$RELEASE_NAME"-slave -n "$NAMESPACE" --timeout="$TIMEOUT"
    fi
    
    # Check MySQL statefulset
    if kubectl get statefulset -n "$NAMESPACE" "$RELEASE_NAME"-mysql &> /dev/null; then
        print_info "检查 MySQL statefulset 状态..."
        kubectl rollout status statefulset/"$RELEASE_NAME"-mysql -n "$NAMESPACE" --timeout="$TIMEOUT"
    fi
    
    # Check Redis statefulset
    if kubectl get statefulset -n "$NAMESPACE" "$RELEASE_NAME"-redis &> /dev/null; then
        print_info "检查 Redis statefulset 状态..."
        kubectl rollout status statefulset/"$RELEASE_NAME"-redis -n "$NAMESPACE" --timeout="$TIMEOUT"
    fi
}

# Function to show rollback instructions
show_rollback_instructions() {
    print_error "升级失败！以下是回滚说明："
    
    cat << EOF

${YELLOW}回滚选项：${NC}

1. 回滚到上一个版本：
   helm rollback $RELEASE_NAME -n $NAMESPACE

2. 回滚到特定版本：
   helm history $RELEASE_NAME -n $NAMESPACE
   helm rollback $RELEASE_NAME [REVISION] -n $NAMESPACE

3. 如果有备份，可以从备份恢复：
   $([ -f .last-backup-dir ] && echo "备份目录：$(cat .last-backup-dir)" || echo "未找到备份目录")

EOF
}

# Function to show post-upgrade info
show_post_upgrade_info() {
    cat << EOF

${GREEN}升级完成！${NC}

${BLUE}后续步骤：${NC}

1. 验证应用功能：
   kubectl get pods -n $NAMESPACE
   kubectl logs -f deployment/$RELEASE_NAME-master -n $NAMESPACE

2. 检查服务状态：
   kubectl get svc -n $NAMESPACE

3. 如果启用了 ingress，检查 ingress：
   kubectl get ingress -n $NAMESPACE

4. 查看升级历史：
   helm history $RELEASE_NAME -n $NAMESPACE

5. 如果需要回滚：
   helm rollback $RELEASE_NAME -n $NAMESPACE

EOF
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
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -c|--chart)
            CHART_PATH="$2"
            shift 2
            ;;
        --no-backup)
            BACKUP_BEFORE_UPGRADE=false
            shift
            ;;
        --no-wait)
            WAIT_FOR_READY=false
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
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
    print_info "开始 New-API 升级..."
    print_info "命名空间：$NAMESPACE"
    print_info "Release 名称：$RELEASE_NAME"
    print_info "Chart 路径：$CHART_PATH"
    
    check_prerequisites
    check_release_exists
    show_current_release_info
    validate_values_file
    backup_current_release
    perform_upgrade
    
    if [ "$DRY_RUN" = false ]; then
        show_post_upgrade_info
    fi
}

# Run main function
main