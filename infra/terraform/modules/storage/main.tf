# Storage Module
# Creates Azure Storage Account with Azure Files and private endpoint

# Random suffix for globally unique storage account name
resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  special = false
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = "${replace(var.name_prefix, "-", "")}st${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  
  # Security settings
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  
  # Enable soft delete for files
  share_properties {
    retention_policy {
      days = 7
    }
  }
  
  tags = var.tags
}

# Azure Files Share
resource "azurerm_storage_share" "fleetpulse" {
  name                 = "fleetpulse"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 100 # GB
  
  depends_on = [azurerm_storage_account.main]
}

# Private DNS Zone for Storage Account
resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = "${var.name_prefix}-storage-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage" {
  name                = "${var.name_prefix}-st-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.privatelink_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name_prefix}-st-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage.id]
  }
}