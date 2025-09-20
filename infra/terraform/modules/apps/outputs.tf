output "managed_identity_id" {
  description = "ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.apps.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the user-assigned managed identity"
  value       = azurerm_user_assigned_identity.apps.principal_id
}

output "backend_app_id" {
  description = "ID of the backend Container App"
  value       = azurerm_container_app.backend.id
}

output "frontend_app_id" {
  description = "ID of the frontend Container App"
  value       = azurerm_container_app.frontend.id
}

output "otel_collector_app_id" {
  description = "ID of the OpenTelemetry Collector Container App"
  value       = azurerm_container_app.otel_collector.id
}

output "backend_fqdn" {
  description = "FQDN of the backend application"
  value       = azurerm_container_app.backend.ingress[0].fqdn
}

output "frontend_fqdn" {
  description = "FQDN of the frontend application"
  value       = azurerm_container_app.frontend.ingress[0].fqdn
}

output "otel_collector_fqdn" {
  description = "FQDN of the OpenTelemetry Collector"
  value       = azurerm_container_app.otel_collector.ingress[0].fqdn
}