output "container_app_environment_id" {
  description = "ID of the Container Apps Environment"
  value       = azurerm_container_app_environment.main.id
}

output "static_ip" {
  description = "Static IP address of the Container Apps Environment internal load balancer"
  value       = data.azurerm_container_app_environment.main.static_ip_address
}

output "default_domain" {
  description = "Default domain of the Container Apps Environment"
  value       = data.azurerm_container_app_environment.main.default_domain
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone for the Container Apps Environment"
  value       = azurerm_private_dns_zone.aca_env.id
}