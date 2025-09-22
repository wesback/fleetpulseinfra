# Monitor Module
# Creates Log Analytics Workspace, Application Insights, and Azure Monitor Private Link Scope (AMPLS)

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.name_prefix}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.name_prefix}-ai"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  
  # Disable public ingestion and queries
  internet_ingestion_enabled = false
  internet_query_enabled     = false
  
  tags = var.tags
}

# Azure Monitor Private Link Scope (AMPLS)
resource "azurerm_monitor_private_link_scope" "main" {
  name                = "${var.name_prefix}-ampls"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Log Analytics Workspace to AMPLS
resource "azurerm_monitor_private_link_scoped_service" "law" {
  name                = "${var.name_prefix}-law-scoped"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_log_analytics_workspace.main.id
}

# Link Application Insights to AMPLS
resource "azurerm_monitor_private_link_scoped_service" "ai" {
  name                = "${var.name_prefix}-ai-scoped"
  resource_group_name = var.resource_group_name
  scope_name          = azurerm_monitor_private_link_scope.main.name
  linked_resource_id  = azurerm_application_insights.main.id
}

# Private DNS Zone for Azure Monitor
resource "azurerm_private_dns_zone" "monitor" {
  name                = "privatelink.monitor.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Additional DNS zones for Azure Monitor services
resource "azurerm_private_dns_zone" "oms" {
  name                = "privatelink.oms.opinsights.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "ods" {
  name                = "privatelink.ods.opinsights.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "agentsvc" {
  name                = "privatelink.agentsvc.azure-automation.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link Private DNS Zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "monitor" {
  name                  = "${var.name_prefix}-monitor-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.monitor.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "oms" {
  name                  = "${var.name_prefix}-oms-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.oms.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ods" {
  name                  = "${var.name_prefix}-ods-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.ods.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "agentsvc" {
  name                  = "${var.name_prefix}-agentsvc-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.agentsvc.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# Private Endpoint for AMPLS
resource "azurerm_private_endpoint" "monitor" {
  name                = "${var.name_prefix}-monitor-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.privatelink_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name_prefix}-monitor-psc"
    private_connection_resource_id = azurerm_monitor_private_link_scope.main.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "monitor-dns-zone-group"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.monitor.id
    ]
  }
}

# Store Application Insights connection string in Key Vault
resource "azurerm_key_vault_secret" "app_insights_connection_string" {
  name         = "app-insights-connection-string"
  value        = azurerm_application_insights.main.connection_string
  key_vault_id = var.key_vault_id
  content_type = "text/plain"
  tags         = var.tags
}