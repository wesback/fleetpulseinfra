output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_share_name" {
  description = "Name of the Azure Files share"
  value       = var.create_storage_share ? azapi_resource.storage_share[0].name : null
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account (will be null because shared key auth is disabled by policy)"
  value       = var.shared_access_key_enabled ? try(azurerm_storage_account.main.primary_access_key, null) : null
  sensitive   = true
}

output "private_endpoint_id" {
  description = "ID of the storage private endpoint"
  value       = azurerm_private_endpoint.storage.id
}