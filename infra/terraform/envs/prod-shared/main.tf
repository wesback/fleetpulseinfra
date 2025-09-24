# FleetPulse Production Shared Infrastructure Layer
# Contains: Key Vault, Storage, Monitor (Log Analytics, App Insights)

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

# Azure Files storage with private endpoint
module "storage" {
  source = "../../modules/storage"

  resource_group_name   = data.terraform_remote_state.network.outputs.resource_group_name
  location              = data.terraform_remote_state.network.outputs.location
  name_prefix           = local.name_prefix
  vnet_id               = data.terraform_remote_state.network.outputs.vnet_id
  privatelink_subnet_id = data.terraform_remote_state.network.outputs.privatelink_subnet_id
  tags                  = local.common_tags
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
}

# Key Vault for secrets and certificates
module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name        = data.terraform_remote_state.network.outputs.resource_group_name
  location                   = data.terraform_remote_state.network.outputs.location
  name_prefix                = local.name_prefix
  vnet_id                    = data.terraform_remote_state.network.outputs.vnet_id
  privatelink_subnet_id      = data.terraform_remote_state.network.outputs.privatelink_subnet_id
  tags                       = local.common_tags
  manage_placeholder_secrets = false
}

# Azure Monitor with Application Insights and AMPLS
module "monitor" {
  source = "../../modules/monitor"

  resource_group_name                  = data.terraform_remote_state.network.outputs.resource_group_name
  location                             = data.terraform_remote_state.network.outputs.location
  name_prefix                          = local.name_prefix
  vnet_id                              = data.terraform_remote_state.network.outputs.vnet_id
  privatelink_subnet_id                = data.terraform_remote_state.network.outputs.privatelink_subnet_id
  key_vault_id                         = module.keyvault.key_vault_id
  tags                                 = local.common_tags
  depends_on                           = [module.keyvault]
  store_app_insights_connection_string = false
}