output "dns_resolver_id" {
  description = "ID of the DNS Private Resolver"
  value       = azurerm_private_dns_resolver.main.id
}

output "inbound_endpoint_id" {
  description = "ID of the inbound endpoint"
  value       = azurerm_private_dns_resolver_inbound_endpoint.main.id
}

output "inbound_endpoint_ip" {
  description = "IP address of the inbound endpoint for conditional forwarding"
  value       = azurerm_private_dns_resolver_inbound_endpoint.main.ip_configurations[0].private_ip_address
}