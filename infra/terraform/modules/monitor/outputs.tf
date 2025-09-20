output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "application_insights_id" {
  description = "ID of Application Insights"
  value       = azurerm_application_insights.main.id
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = azurerm_application_insights.main.name
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "app_insights_connection_string_secret_uri" {
  description = "Key Vault secret URI for Application Insights connection string"
  value       = azurerm_key_vault_secret.app_insights_connection_string.versionless_id
}

output "monitor_private_link_scope_id" {
  description = "ID of the Azure Monitor Private Link Scope"
  value       = azurerm_monitor_private_link_scope.main.id
}

output "private_endpoint_id" {
  description = "ID of the monitor private endpoint"
  value       = azurerm_private_endpoint.monitor.id
}