# Shared Layer Outputs
# These outputs are consumed by downstream layers via remote state

# Key Vault
output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.keyvault.key_vault_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.keyvault.key_vault_uri
}

# Storage
output "storage_account_id" {
  description = "ID of the storage account"
  value       = module.storage.storage_account_id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage.storage_account_name
}

output "storage_share_name" {
  description = "Name of the Azure Files share"
  value       = module.storage.storage_share_name
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account"
  value       = module.storage.storage_account_primary_access_key
  sensitive   = true
}

# Monitor
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = module.monitor.log_analytics_workspace_id
}

output "application_insights_id" {
  description = "ID of Application Insights"
  value       = module.monitor.application_insights_id
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = module.monitor.application_insights_name
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = module.monitor.application_insights_connection_string
  sensitive   = true
}

output "app_insights_connection_string_secret_uri" {
  description = "Key Vault secret URI for Application Insights connection string (null when not stored)"
  value       = module.monitor.app_insights_connection_string_secret_uri
}