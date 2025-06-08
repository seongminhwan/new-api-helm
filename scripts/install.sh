#!/bin/bash

# New-API Helm Chart Installation Script
# This script helps you install the New-API Helm chart with different configurations

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
CREATE_NAMESPACE=true
DRY_RUN=false

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
    --no-create-namespace           Don't create namespace if it doesn't exist
    --dry-run                       Perform a dry run
    -h, --help                      Show this help message

Examples:
    # Install with default values
    $0

    # Install with production values
    $0 -f examples/values-production.yaml

    # Install with development values
    $0 -f examples/values-development.yaml -n new-api-dev

    # Install with external database
    $0 -f examples/values-external-db.yaml

    # Dry run with custom namespace
    $0 -n my-namespace --dry-run

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    if [ "$CREATE_NAMESPACE" = true ]; then
        if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
            print_info "Creating namespace: $NAMESPACE"
            kubectl create namespace "$NAMESPACE"
            print_success "Namespace $NAMESPACE created"
        else
            print_info "Namespace $NAMESPACE already exists"
        fi
    fi
}

# Function to validate values file
validate_values_file() {
    if [ -n "$VALUES_FILE" ]; then
        if [ ! -f "$VALUES_FILE" ]; then
            print_error "Values file not found: $VALUES_FILE"
            exit 1
        fi
        print_info "Using values file: $VALUES_FILE"
    else
        print_info "Using default values"
    fi
}

# Function to install the chart
install_chart() {
    print_info "Installing New-API Helm chart..."
    
    local helm_cmd="helm install $RELEASE_NAME $CHART_PATH --namespace $NAMESPACE"
    
    if [ -n "$VALUES_FILE" ]; then
        helm_cmd="$helm_cmd --values $VALUES_FILE"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        helm_cmd="$helm_cmd --dry-run"
        print_info "Performing dry run..."
    fi
    
    if eval "$helm_cmd"; then
        if [ "$DRY_RUN" = false ]; then
            print_success "New-API has been installed successfully!"
            print_info "Release name: $RELEASE_NAME"
            print_info "Namespace: $NAMESPACE"
            
            # Show status
            print_info "Checking deployment status..."
            helm status "$RELEASE_NAME" -n "$NAMESPACE"
            
            # Show next steps
            show_next_steps
        else
            print_success "Dry run completed successfully!"
        fi
    else
        print_error "Failed to install New-API"
        exit 1
    fi
}

# Function to show next steps
show_next_steps() {
    cat << EOF

${GREEN}Next Steps:${NC}

1. Check the status of your deployment:
   kubectl get pods -n $NAMESPACE

2. Check the services:
   kubectl get svc -n $NAMESPACE

3. If you enabled ingress, check the ingress:
   kubectl get ingress -n $NAMESPACE

4. To access the application:
   - If using NodePort: kubectl get svc $RELEASE_NAME -n $NAMESPACE
   - If using LoadBalancer: Wait for external IP and access via that IP
   - If using Ingress: Access via the configured hostname

5. To view logs:
   kubectl logs -f deployment/$RELEASE_NAME-master -n $NAMESPACE

6. To upgrade the deployment:
   helm upgrade $RELEASE_NAME $CHART_PATH -n $NAMESPACE

7. To uninstall:
   helm uninstall $RELEASE_NAME -n $NAMESPACE

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
        --no-create-namespace)
            CREATE_NAMESPACE=false
            shift
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
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_info "Starting New-API installation..."
    print_info "Namespace: $NAMESPACE"
    print_info "Release name: $RELEASE_NAME"
    print_info "Chart path: $CHART_PATH"
    
    check_prerequisites
    validate_values_file
    create_namespace
    install_chart
}

# Run main function
main