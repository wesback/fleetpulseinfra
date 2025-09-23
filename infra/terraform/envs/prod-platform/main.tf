# FleetPulse Production Platform Infrastructure Layer
# Contains: Container Apps Environment, Policy

locals {
  # Common naming convention
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# Get network layer outputs via remote state
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_rg
    storage_account_name = var.backend_sa
    container_name       = var.backend_container
    key                  = "prod-network.tfstate"
    # use_azuread_auth    = true
  }
}

# Get shared layer outputs via remote state
data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_rg
    storage_account_name = var.backend_sa
    container_name       = var.backend_container
    key                  = "prod-shared.tfstate"
    # use_azuread_auth    = true
  }
}

# Azure Policy for Container Apps security
module "policy" {
  source = "../../modules/policy"

  resource_group_id = data.terraform_remote_state.network.outputs.resource_group_id
}

# Container Apps Environment with internal load balancer
module "aca_env" {
  source = "../../modules/aca_env"

  resource_group_name        = data.terraform_remote_state.network.outputs.resource_group_name
  location                   = data.terraform_remote_state.network.outputs.location
  name_prefix                = local.name_prefix
  aca_subnet_id              = data.terraform_remote_state.network.outputs.aca_subnet_id
  vnet_id                    = data.terraform_remote_state.network.outputs.vnet_id
  log_analytics_workspace_id = data.terraform_remote_state.shared.outputs.log_analytics_workspace_id
  workload_profile           = var.aca_workload_profile
  custom_domains             = var.custom_domains
  tags                       = local.common_tags

  # No firewall dependency needed for simple web app deployment
}