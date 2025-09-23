# Key Vault Module
# Creates Azure Key Vault with RBAC and private endpoint for secrets and certificates

# Get current client configuration
data "azurerm_client_config" "current" {}

# Random suffix for globally unique Key Vault name
resource "random_string" "keyvault_suffix" {
  length  = 6
  upper   = false
  special = false
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                        = "kv-${substr(replace(replace(var.name_prefix, "_", "-"), "fleetpulse-", "fp-"), 0, 10)}-${random_string.keyvault_suffix.result}"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name                    = "standard"
  
  # Disable public access
  public_network_access_enabled = false
  
  # Use RBAC instead of access policies
  rbac_authorization_enabled = true
  
  tags = var.tags
}

# Grant the deploying principal permissions to manage secrets in the Key Vault
# Required because rbac_authorization_enabled = true disables access policies
resource "azurerm_role_assignment" "kv_secrets_officer_deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${var.name_prefix}-kv-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.name_prefix}-kv-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.privatelink_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name_prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}

# Placeholder secrets that will be populated during deployment
# These are created with dummy values and updated by CI/CD

resource "azurerm_key_vault_secret" "cert_pfx" {
  count        = var.manage_placeholder_secrets ? 1 : 0
  name         = "ssl-cert-pfx"
  value        = "placeholder-will-be-updated-by-cicd"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "application/x-pkcs12"
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_deployer]
}

resource "azurerm_key_vault_secret" "cert_password" {
  count        = var.manage_placeholder_secrets ? 1 : 0
  name         = "ssl-cert-password"
  value        = "placeholder-will-be-updated-by-cicd"
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"
  tags         = var.tags
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_deployer]
}