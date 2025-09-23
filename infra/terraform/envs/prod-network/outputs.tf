# Network Layer Outputs
# These outputs are consumed by downstream layers via remote state

# Resource Group
output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}

# VNet and Subnets
output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.vnet.vnet_id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.vnet.vnet_name
}

output "aca_subnet_id" {
  description = "ID of the Container Apps subnet"
  value       = module.vnet.aca_subnet_id
}

output "privatelink_subnet_id" {
  description = "ID of the Private Link subnet"
  value       = module.vnet.privatelink_subnet_id
}

output "gateway_subnet_id" {
  description = "ID of the VPN Gateway subnet"
  value       = module.vnet.gateway_subnet_id
}

output "dns_resolver_inbound_subnet_id" {
  description = "ID of the DNS Resolver inbound subnet"
  value       = module.vnet.dns_resolver_inbound_subnet_id
}

# Gateway
output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = module.gateway.vpn_gateway_id
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = module.gateway.vpn_gateway_public_ip
}

# DNS Resolver
output "dns_resolver_id" {
  description = "ID of the DNS Private Resolver"
  value       = module.dns_resolver.dns_resolver_id
}

output "dns_resolver_inbound_ip" {
  description = "Inbound IP address of the DNS Private Resolver"
  value       = module.dns_resolver.inbound_endpoint_ip
}