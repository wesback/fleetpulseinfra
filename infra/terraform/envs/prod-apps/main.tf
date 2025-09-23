# FleetPulse Production Apps Infrastructure Layer
# Contains: Container Apps (backend, frontend, otel-collector)

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

# Get platform layer outputs via remote state
data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_rg
    storage_account_name = var.backend_sa
    container_name       = var.backend_container
    key                  = "prod-platform.tfstate"
    # use_azuread_auth    = true
  }
}

# Container Apps (backend, frontend, otel-collector)
module "apps" {
  source = "../../modules/apps"

  resource_group_name                               = data.terraform_remote_state.network.outputs.resource_group_name
  location                                          = data.terraform_remote_state.network.outputs.location
  name_prefix                                       = local.name_prefix
  container_app_environment_id                      = data.terraform_remote_state.platform.outputs.container_app_environment_id
  container_app_environment_domain                  = data.terraform_remote_state.platform.outputs.default_domain
  key_vault_id                                      = data.terraform_remote_state.shared.outputs.key_vault_id
  application_insights_connection_string_secret_uri = data.terraform_remote_state.shared.outputs.app_insights_connection_string_secret_uri
  application_insights_connection_string            = data.terraform_remote_state.shared.outputs.application_insights_connection_string
  container_images                                  = var.container_images
  custom_domains                                    = var.custom_domains
  home_cidrs                                        = var.home_cidrs
  app_resources                                     = var.app_resources
  workload_profile_name                             = data.terraform_remote_state.platform.outputs.workload_profile_name
  tags                                              = local.common_tags
}