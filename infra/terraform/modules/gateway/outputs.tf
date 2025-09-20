output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.id
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

output "local_network_gateway_id" {
  description = "ID of the Local Network Gateway"
  value       = azurerm_local_network_gateway.opnsense.id
}

output "vpn_connection_id" {
  description = "ID of the VPN connection"
  value       = azurerm_virtual_network_gateway_connection.s2s.id
}