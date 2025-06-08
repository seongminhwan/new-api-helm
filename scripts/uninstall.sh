#!/bin/bash

# New-API Helm Chart Uninstallation Script
# This script helps you safely uninstall the New-API Helm chart

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
DELETE_NAMESPACE=false
DELETE_PVC=false
FORCE=false
BACKUP_DATA=false

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
    --delete-namespace              Delete the namespace after uninstalling
    --delete-pvc                    Delete persistent volume claims (WARNING: This will delete all data!)
    --backup-data                   Create a backup before deletion
    --force                         Skip confirmation prompts
    -h, --help                      Show this help message

Examples:
    # Basic uninstall
    $0

    # Uninstall and delete namespace
    $0 --delete-namespace

    # Uninstall with data backup and PVC deletion
    $0 --backup-data --delete-pvc

    # Force uninstall without prompts
    $0 --force --delete-pvc --delete-namespace

EOF
}

# Function to confirm action
confirm_action() {
    if [ "$FORCE" = false ]; then
        echo -e "${YELLOW}Are you sure you want to proceed? (y/N):${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled"
            exit 0
        fi
    fi
}

# Function to check if release exists
check_release_exists() {
    if ! helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        print_error "Release $RELEASE_NAME not found in namespace $NAMESPACE"
        exit 1
    fi
}

# Function to backup data
backup_data() {
    if [ "$BACKUP_DATA" = true ]; then
        print_info "Creating backup before deletion..."
        
        local backup_dir="backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        
        # Backup MySQL data if exists
        if kubectl get pvc -n "$NAMESPACE" | grep -q mysql; then
            print_info "Backing up MySQL data..."
            kubectl exec -n "$NAMESPACE" deployment/"$RELEASE_NAME"-mysql -- mysqldump -u root -p"$(kubectl get secret -n "$NAMESPACE" "$RELEASE_NAME"-mysql -o jsonpath='{.data.mysql-root-password}' | base64 -d)" --all-databases > "$backup_dir/mysql-backup.sql" 2>/dev/null || print_warning "MySQL backup failed"
        fi
        
        # Backup Redis data if exists
        if kubectl get pvc -n "$NAMESPACE" | grep -q redis; then
            print_info "Backing up Redis data..."
            kubectl exec -n "$NAMESPACE" statefulset/"$RELEASE_NAME"-redis -- redis-cli --rdb /tmp/dump.rdb 2>/dev/null || print_warning "Redis backup failed"
            kubectl cp "$NAMESPACE"/"$RELEASE_NAME"-redis-0:/tmp/dump.rdb "$backup_dir/redis-dump.rdb" 2>/dev/null || print_warning "Redis backup copy failed"
        fi
        
        # Backup application data
        if kubectl get pvc -n "$NAMESPACE" | grep -q "$RELEASE_NAME"-master; then
            print_info "Backing up application data..."
            kubectl exec -n "$NAMESPACE" deployment/"$RELEASE_NAME"-master -- tar czf /tmp/app-backup.tar.gz /app/data /app/logs 2>/dev/null || print_warning "Application backup failed"
            kubectl cp "$NAMESPACE"/"$RELEASE_NAME"-master:/tmp/app-backup.tar.gz "$backup_dir/app-backup.tar.gz" 2>/dev/null || print_warning "Application backup copy failed"
        fi
        
        print_success "Backup created in directory: $backup_dir"
    fi
}

# Function to uninstall helm release
uninstall_release() {
    print_info "Uninstalling Helm release: $RELEASE_NAME"
    
    if helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"; then
        print_success "Helm release $RELEASE_NAME uninstalled successfully"
    else
        print_error "Failed to uninstall Helm release"
        exit 1
    fi
}

# Function to delete PVCs
delete_pvcs() {
    if [ "$DELETE_PVC" = true ]; then
        print_warning "This will permanently delete all persistent data!"
        confirm_action
        
        print_info "Deleting persistent volume claims..."
        
        # Get all PVCs related to the release
        local pvcs
        pvcs=$(kubectl get pvc -n "$NAMESPACE" -o name | grep "$RELEASE_NAME" || true)
        
        if [ -n "$pvcs" ]; then
            echo "$pvcs" | while read -r pvc; do
                print_info "Deleting $pvc"
                kubectl delete "$pvc" -n "$NAMESPACE"
            done
            print_success "All PVCs deleted"
        else
            print_info "No PVCs found for release $RELEASE_NAME"
        fi
    fi
}

# Function to delete namespace
delete_namespace() {
    if [ "$DELETE_NAMESPACE" = true ]; then
        print_warning "This will delete the entire namespace: $NAMESPACE"
        confirm_action
        
        print_info "Deleting namespace: $NAMESPACE"
        
        if kubectl delete namespace "$NAMESPACE"; then
            print_success "Namespace $NAMESPACE deleted successfully"
        else
            print_error "Failed to delete namespace"
            exit 1
        fi
    fi
}

# Function to show cleanup status
show_cleanup_status() {
    print_info "Cleanup completed!"
    
    if [ "$DELETE_NAMESPACE" = false ]; then
        print_info "Remaining resources in namespace $NAMESPACE:"
        kubectl get all -n "$NAMESPACE" 2>/dev/null || print_info "No resources found"
        
        if [ "$DELETE_PVC" = false ]; then
            print_info "Remaining PVCs in namespace $NAMESPACE:"
            kubectl get pvc -n "$NAMESPACE" 2>/dev/null || print_info "No PVCs found"
        fi
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
        --delete-namespace)
            DELETE_NAMESPACE=true
            shift
            ;;
        --delete-pvc)
            DELETE_PVC=true
            shift
            ;;
        --backup-data)
            BACKUP_DATA=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_info "Starting New-API uninstallation..."
    print_info "Namespace: $NAMESPACE"
    print_info "Release name: $RELEASE_NAME"
    
    if [ "$DELETE_PVC" = true ]; then
        print_warning "PVC deletion is enabled - all data will be lost!"
    fi
    
    if [ "$DELETE_NAMESPACE" = true ]; then
        print_warning "Namespace deletion is enabled"
    fi
    
    # Check prerequisites
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if release exists
    check_release_exists
    
    # Confirm the operation
    print_warning "You are about to uninstall New-API release: $RELEASE_NAME from namespace: $NAMESPACE"
    confirm_action
    
    # Execute uninstallation steps
    backup_data
    uninstall_release
    delete_pvcs
    delete_namespace
    show_cleanup_status
    
    print_success "New-API uninstallation completed!"
}

# Run main function
main