# DNS Private Resolver Module
# Creates Azure DNS Private Resolver for conditional forwarding from on-premises

# DNS Private Resolver
resource "azurerm_private_dns_resolver" "main" {
  name                = "${var.name_prefix}-dns-resolver"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_network_id  = var.vnet_id
  tags                = var.tags
}

# Inbound Endpoint for on-premises conditional forwarding
resource "azurerm_private_dns_resolver_inbound_endpoint" "main" {
  name                    = "${var.name_prefix}-dns-inbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.main.id
  location                = var.location
  tags                    = var.tags

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = var.dns_resolver_inbound_subnet_id
  }
}