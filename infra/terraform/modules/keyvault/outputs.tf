output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "cert_pfx_secret_id" {
  description = "Secret ID for the PFX certificate"
  value       = azurerm_key_vault_secret.cert_pfx.id
}

output "cert_password_secret_id" {
  description = "Secret ID for the certificate password"
  value       = azurerm_key_vault_secret.cert_password.id
}

output "private_endpoint_id" {
  description = "ID of the Key Vault private endpoint"
  value       = azurerm_private_endpoint.keyvault.id
}