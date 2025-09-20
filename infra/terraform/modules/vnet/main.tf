# Virtual Network Module
# Creates VNET with all required subnets for FleetPulse infrastructure

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Container Apps Infrastructure Subnet
resource "azurerm_subnet" "aca_infra" {
  name                 = "snet-aca-infra"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs.aca_infra]

  # Container Apps requires delegation
  delegation {
    name = "Microsoft.App.environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# VPN Gateway Subnet (must be named exactly "GatewaySubnet")
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs.gateway]
}

# Private Link Subnet for private endpoints
resource "azurerm_subnet" "privatelink" {
  name                 = "snet-privatelink"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs.privatelink]
}

# Azure Firewall Subnet (must be named exactly "AzureFirewallSubnet")
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs.firewall]
}

# DNS Resolver Inbound Subnet
resource "azurerm_subnet" "dns_resolver_inbound" {
  name                 = "snet-dnsresolver-inbound"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidrs.dns_resolver_inbound]

  # DNS Private Resolver requires delegation
  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}