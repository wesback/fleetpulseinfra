# FleetPulse Production Network Infrastructure Layer
# Contains: Resource Group, VNet, VPN Gateway, DNS Resolver

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