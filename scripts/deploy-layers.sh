#!/bin/bash

# FleetPulse Layered Terraform Deployment Script
# This script helps deploy the layered Terraform infrastructure in the correct order

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../infra/terraform/envs"
LAYERS=("prod-network" "prod-shared" "prod-platform" "prod-apps")

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND] [LAYER]"
    echo ""
    echo "Commands:"
    echo "  init       Initialize all layers or specific layer"
    echo "  plan       Plan all layers or specific layer"
    echo "  apply      Apply all layers or specific layer"
    echo "  destroy    Destroy all layers or specific layer (reverse order)"
    echo "  status     Show status of all layers"
    echo "  validate   Validate all layer configurations"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -y, --yes      Auto-approve applies (use with caution)"
    echo "  -v, --verbose  Verbose output"
    echo ""
    echo "Layers (in dependency order):"
    for layer in "${LAYERS[@]}"; do
        echo "  - $layer"
    done
    echo ""
    echo "Examples:"
    echo "  $0 plan                    # Plan all layers"
    echo "  $0 apply prod-network      # Apply network layer only"
    echo "  $0 status                  # Show status of all layers"
    echo "  $0 destroy --yes           # Destroy all layers (auto-approve)"
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if layer exists
layer_exists() {
    local layer=$1
    [[ -d "$TERRAFORM_DIR/$layer" ]]
}

# Check if layer is valid
is_valid_layer() {
    local layer=$1
    for valid_layer in "${LAYERS[@]}"; do
        if [[ "$layer" == "$valid_layer" ]]; then
            return 0
        fi
    done
    return 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check if logged into Azure
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Run 'az login' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Initialize layer
init_layer() {
    local layer=$1
    local layer_dir="$TERRAFORM_DIR/$layer"
    local backend_conf="$layer_dir/backend.conf"
    
    log_info "Initializing layer: $layer"
    
    if [[ ! -f "$backend_conf" ]]; then
        if [[ -f "$layer_dir/backend.conf.example" ]]; then
            log_warning "backend.conf not found, copying from example"
            cp "$layer_dir/backend.conf.example" "$layer_dir/backend.conf"
            log_warning "Please edit $layer_dir/backend.conf with your actual values"
        else
            log_error "No backend configuration found for $layer"
            return 1
        fi
    fi

    if ! grep -Eq '^\s*use_azuread_auth\s*=\s*true' "$backend_conf"; then
        log_error "use_azuread_auth must be set to true in $backend_conf. Azure Policy blocks shared key auth; update the backend configuration to rely on Azure AD before continuing."
        exit 1
    fi

    if grep -Eq '^\s*(access_key|sas_token)\s*=' "$backend_conf"; then
        log_error "Key-based credentials found in $backend_conf. Remove access_key/sas_token entries and rely on Azure AD authentication."
        exit 1
    fi

    local backend_rg
    backend_rg=$(grep -E '^\s*resource_group_name' "$backend_conf" | tail -n1 | awk -F'=' '{print $2}' | tr -d ' "')
    local backend_sa
    backend_sa=$(grep -E '^\s*storage_account_name' "$backend_conf" | tail -n1 | awk -F'=' '{print $2}' | tr -d ' "')

    if [[ -n "$backend_rg" && -n "$backend_sa" ]]; then
        local allow_shared_key
        allow_shared_key=$(az storage account show \
            --name "$backend_sa" \
            --resource-group "$backend_rg" \
            --query "allowSharedKeyAccess" \
            -o tsv 2>/dev/null || echo "unknown")

        if [[ "$allow_shared_key" == "true" ]]; then
            log_error "Storage account $backend_sa still allows shared key access. Disable it with: az storage account update --name $backend_sa --resource-group $backend_rg --allow-shared-key-access false"
            exit 1
        elif [[ "$allow_shared_key" == "false" ]]; then
            log_info "Shared key access already disabled for storage account $backend_sa"
        else
            log_warning "Could not verify shared key access for storage account $backend_sa (resource group: $backend_rg)."
        fi
    fi
    
    cd "$layer_dir"
    terraform init -backend-config=backend.conf
    log_success "Layer $layer initialized"
}

# Plan layer
plan_layer() {
    local layer=$1
    local layer_dir="$TERRAFORM_DIR/$layer"
    
    log_info "Planning layer: $layer"
    
    cd "$layer_dir"
    if terraform plan -detailed-exitcode -no-color; then
        log_success "Layer $layer: No changes needed"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            log_warning "Layer $layer: Changes detected"
            return 2
        else
            log_error "Layer $layer: Plan failed"
            return 1
        fi
    fi
}

# Apply layer
apply_layer() {
    local layer=$1
    local auto_approve=${2:-false}
    local layer_dir="$TERRAFORM_DIR/$layer"
    
    log_info "Applying layer: $layer"
    
    cd "$layer_dir"
    if [[ "$auto_approve" == "true" ]]; then
        terraform apply -auto-approve
    else
        terraform apply
    fi
    log_success "Layer $layer applied successfully"
}

# Destroy layer
destroy_layer() {
    local layer=$1
    local auto_approve=${2:-false}
    local layer_dir="$TERRAFORM_DIR/$layer"
    
    log_warning "Destroying layer: $layer"
    
    cd "$layer_dir"
    if [[ "$auto_approve" == "true" ]]; then
        terraform destroy -auto-approve
    else
        terraform destroy
    fi
    log_success "Layer $layer destroyed"
}

# Show layer status
show_layer_status() {
    local layer=$1
    local layer_dir="$TERRAFORM_DIR/$layer"
    
    echo -n "  $layer: "
    
    if [[ ! -d "$layer_dir" ]]; then
        echo -e "${RED}Missing${NC}"
        return
    fi
    
    cd "$layer_dir"
    
    if [[ ! -f ".terraform/terraform.tfstate" ]]; then
        echo -e "${YELLOW}Not initialized${NC}"
        return
    fi
    
    if terraform plan -detailed-exitcode &>/dev/null; then
        echo -e "${GREEN}Up to date${NC}"
    else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            echo -e "${YELLOW}Changes pending${NC}"
        else
            echo -e "${RED}Error${NC}"
        fi
    fi
}

# Validate layer
validate_layer() {
    local layer=$1
    local layer_dir="$TERRAFORM_DIR/$layer"
    
    log_info "Validating layer: $layer"
    
    cd "$layer_dir"
    terraform fmt -check
    terraform validate
    log_success "Layer $layer validation passed"
}

# Process all layers or specific layer
process_layers() {
    local command=$1
    local specific_layer=${2:-}
    local auto_approve=${3:-false}
    
    local layers_to_process=()
    
    if [[ -n "$specific_layer" ]]; then
        if ! is_valid_layer "$specific_layer"; then
            log_error "Invalid layer: $specific_layer"
            exit 1
        fi
        layers_to_process=("$specific_layer")
    else
        if [[ "$command" == "destroy" ]]; then
            # Reverse order for destroy
            for ((i=${#LAYERS[@]}-1; i>=0; i--)); do
                layers_to_process+=("${LAYERS[i]}")
            done
        else
            layers_to_process=("${LAYERS[@]}")
        fi
    fi
    
    for layer in "${layers_to_process[@]}"; do
        if ! layer_exists "$layer"; then
            log_error "Layer directory not found: $layer"
            exit 1
        fi
        
        case "$command" in
            "init")
                init_layer "$layer"
                ;;
            "plan")
                plan_layer "$layer"
                ;;
            "apply")
                apply_layer "$layer" "$auto_approve"
                ;;
            "destroy")
                destroy_layer "$layer" "$auto_approve"
                ;;
            "validate")
                validate_layer "$layer"
                ;;
        esac
    done
}

# Show status of all layers
show_status() {
    log_info "Terraform Layer Status:"
    for layer in "${LAYERS[@]}"; do
        show_layer_status "$layer"
    done
}

# Main function
main() {
    local command=""
    local layer=""
    local auto_approve=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -y|--yes)
                auto_approve=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                set -x
                shift
                ;;
            init|plan|apply|destroy|status|validate)
                command=$1
                shift
                ;;
            prod-*)
                layer=$1
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [[ -z "$command" ]]; then
        log_error "No command specified"
        usage
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Execute command
    case "$command" in
        "status")
            show_status
            ;;
        "init"|"plan"|"apply"|"destroy"|"validate")
            process_layers "$command" "$layer" "$auto_approve"
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
    
    log_success "Command completed successfully"
}

# Run main function
main "$@"