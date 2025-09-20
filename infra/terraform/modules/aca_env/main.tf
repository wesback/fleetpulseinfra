# Container Apps Environment Module
# Creates Azure Container Apps Environment with internal load balancer

# Container Apps Environment with internal load balancer
resource "azurerm_container_app_environment" "main" {
  name                         = "${var.name_prefix}-aca-env"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  infrastructure_subnet_id     = var.aca_subnet_id
  internal_load_balancer_enabled = true
  tags                         = var.tags

  # Workload profile for egress control via UDR
  workload_profile {
    name                  = var.workload_profile.name
    workload_profile_type = var.workload_profile.workload_profile_type
    minimum_count         = var.workload_profile.minimum_count
    maximum_count         = var.workload_profile.maximum_count
  }
}

# Get the static IP of the Container Apps Environment
data "azurerm_container_app_environment" "main" {
  name                = azurerm_container_app_environment.main.name
  resource_group_name = var.resource_group_name
  depends_on          = [azurerm_container_app_environment.main]
}

# Private DNS Zone for Container Apps Environment default domain
resource "azurerm_private_dns_zone" "aca_env" {
  name                = data.azurerm_container_app_environment.main.default_domain
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Create wildcard A record pointing to the internal load balancer IP
resource "azurerm_private_dns_a_record" "wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.aca_env.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [data.azurerm_container_app_environment.main.static_ip_address]
  tags                = var.tags
}

# Link Private DNS Zone to VNet (this will be the VNet containing the ACA environment)
resource "azurerm_private_dns_zone_virtual_network_link" "aca_env" {
  name                  = "${var.name_prefix}-aca-env-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aca_env.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# Note: Certificate management will be handled by post-deploy scripts
# The environment will support custom domains but certificate binding
# is done via CLI to avoid storing PFX content in Terraform state