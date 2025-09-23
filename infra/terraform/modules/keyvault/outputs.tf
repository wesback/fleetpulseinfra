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
  description = "Secret ID for the PFX certificate (null when not managed)"
  value       = var.manage_placeholder_secrets ? azurerm_key_vault_secret.cert_pfx[0].id : null
}

output "cert_password_secret_id" {
  description = "Secret ID for the certificate password (null when not managed)"
  value       = var.manage_placeholder_secrets ? azurerm_key_vault_secret.cert_password[0].id : null
}

output "private_endpoint_id" {
  description = "ID of the Key Vault private endpoint"
  value       = azurerm_private_endpoint.keyvault.id
}

output "secrets_role_assignment_id" {
  description = "Role assignment ID granting deployer secrets officer role"
  value       = azurerm_role_assignment.kv_secrets_officer_deployer.id
}