output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "aca_subnet_id" {
  description = "ID of the Container Apps subnet"
  value       = azurerm_subnet.aca_infra.id
}

output "gateway_subnet_id" {
  description = "ID of the VPN Gateway subnet"
  value       = azurerm_subnet.gateway.id
}

output "privatelink_subnet_id" {
  description = "ID of the Private Link subnet"
  value       = azurerm_subnet.privatelink.id
}

output "firewall_subnet_id" {
  description = "ID of the Azure Firewall subnet"
  value       = azurerm_subnet.firewall.id
}

output "dns_resolver_inbound_subnet_id" {
  description = "ID of the DNS Resolver inbound subnet"
  value       = azurerm_subnet.dns_resolver_inbound.id
}