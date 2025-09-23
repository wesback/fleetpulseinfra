# FleetPulse Production Infrastructure
# Migrates Docker Compose workload to Azure Container Apps with private networking

locals {
  # Common naming convention
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Virtual Network with subnets
module "vnet" {
  source = "../../modules/vnet"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  vnet_cidr           = var.vnet_cidr
  subnet_cidrs        = var.subnet_cidrs
  tags                = local.common_tags
}

# VPN Gateway for Site-to-Site connection
module "gateway" {
  source = "../../modules/gateway"

  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  name_prefix            = local.name_prefix
  gateway_subnet_id      = module.vnet.gateway_subnet_id
  on_premises_gateway_ip = var.on_premises_gateway_ip
  on_premises_networks   = var.on_premises_networks
  vpn_shared_key         = var.vpn_shared_key
  vpn_gateway_sku        = var.vpn_gateway_sku
  tags                   = local.common_tags
}

# Note: Azure Firewall removed for cost optimization
# For larger deployments or stricter security requirements, consider adding:
# - Azure Firewall for egress traffic control
# - User Defined Routes (UDR) for traffic routing

# DNS Private Resolver for on-premises conditional forwarding
module "dns_resolver" {
  source = "../../modules/dns_resolver"

  resource_group_name            = azurerm_resource_group.main.name
  location                       = azurerm_resource_group.main.location
  name_prefix                    = local.name_prefix
  vnet_id                        = module.vnet.vnet_id
  dns_resolver_inbound_subnet_id = module.vnet.dns_resolver_inbound_subnet_id
  tags                           = local.common_tags
}

# Azure Files storage with private endpoint
module "storage" {
  source = "../../modules/storage"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  name_prefix           = local.name_prefix
  vnet_id               = module.vnet.vnet_id
  privatelink_subnet_id = module.vnet.privatelink_subnet_id
  tags                  = local.common_tags
}

# Key Vault for secrets and certificates
module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  name_prefix           = local.name_prefix
  vnet_id               = module.vnet.vnet_id
  privatelink_subnet_id = module.vnet.privatelink_subnet_id
  tags                  = local.common_tags
  manage_placeholder_secrets = false
}

# Azure Monitor with Application Insights and AMPLS
module "monitor" {
  source = "../../modules/monitor"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  name_prefix           = local.name_prefix
  vnet_id               = module.vnet.vnet_id
  privatelink_subnet_id = module.vnet.privatelink_subnet_id
  key_vault_id          = module.keyvault.key_vault_id
  tags                  = local.common_tags
  depends_on            = [module.keyvault]
  store_app_insights_connection_string = false
}

# Azure Policy for Container Apps security
module "policy" {
  source = "../../modules/policy"

  resource_group_id = azurerm_resource_group.main.id
}

# Container Apps Environment with internal load balancer
module "aca_env" {
  source = "../../modules/aca_env"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  name_prefix                = local.name_prefix
  aca_subnet_id              = module.vnet.aca_subnet_id
  vnet_id                    = module.vnet.vnet_id
  log_analytics_workspace_id = module.monitor.log_analytics_workspace_id
  workload_profile           = var.aca_workload_profile
  custom_domains             = var.custom_domains
  tags                       = local.common_tags

  # No firewall dependency needed for simple web app deployment
}

# Container Apps (backend, frontend, otel-collector)
module "apps" {
  source = "../../modules/apps"

  resource_group_name                               = azurerm_resource_group.main.name
  location                                          = azurerm_resource_group.main.location
  name_prefix                                       = local.name_prefix
  container_app_environment_id                      = module.aca_env.container_app_environment_id
  container_app_environment_domain                  = module.aca_env.default_domain
  key_vault_id                                      = module.keyvault.key_vault_id
  application_insights_connection_string_secret_uri = module.monitor.app_insights_connection_string_secret_uri
  application_insights_connection_string            = module.monitor.application_insights_connection_string
  container_images                                  = var.container_images
  custom_domains                                    = var.custom_domains
  home_cidrs                                        = var.home_cidrs
  app_resources                                     = var.app_resources
  workload_profile_name                             = var.aca_workload_profile.name
  tags                                              = local.common_tags
}