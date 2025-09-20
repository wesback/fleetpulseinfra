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
  value       = azurerm_storage_share.fleetpulse.name
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "private_endpoint_id" {
  description = "ID of the storage private endpoint"
  value       = azurerm_private_endpoint.storage.id
}