# FleetPulse Infrastructure Outputs
# These outputs provide essential information for DNS configuration and validation

output "container_app_environment_static_ip" {
  description = "Static IP address of the Container App Environment (Internal Load Balancer)"
  value       = module.aca_env.static_ip
}

output "container_app_environment_default_domain" {
  description = "Default domain suffix of the Container App Environment"
  value       = module.aca_env.default_domain
}

output "dns_resolver_inbound_ip" {
  description = "Inbound IP address of the DNS Private Resolver for on-premises conditional forwarding"
  value       = module.dns_resolver.inbound_endpoint_ip
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway for OPNsense configuration"
  value       = module.gateway.vpn_gateway_public_ip
}

output "storage_account_name" {
  description = "Name of the Azure Storage Account for Azure Files"
  value       = module.storage.storage_account_name
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = module.keyvault.key_vault_name
}

output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = module.monitor.application_insights_name
}

# DNS Configuration Information
output "dns_configuration" {
  description = "DNS configuration information for on-premises setup"
  value = {
    # Add these A records to Technitium DNS
    a_records = {
      (var.custom_domains.backend)  = module.aca_env.static_ip
      (var.custom_domains.frontend) = module.aca_env.static_ip
    }

    # Configure these conditional forwarders to DNS Resolver inbound IP
    conditional_forwarders = {
      "privatelink.vaultcore.azure.net"   = module.dns_resolver.inbound_endpoint_ip
      "privatelink.file.core.windows.net" = module.dns_resolver.inbound_endpoint_ip
      "privatelink.monitor.azure.com"     = module.dns_resolver.inbound_endpoint_ip
    }

    # Wildcard DNS zone for Container App Environment
    wildcard_zone = {
      zone = module.aca_env.default_domain
      ip   = module.aca_env.static_ip
    }
  }
}

# Resource IDs for CI/CD reference
output "resource_ids" {
  description = "Resource IDs for CI/CD pipelines"
  value = {
    resource_group_id            = azurerm_resource_group.main.id
    container_app_environment_id = module.aca_env.container_app_environment_id
    key_vault_id                 = module.keyvault.key_vault_id
    storage_account_id           = module.storage.storage_account_id
    log_analytics_workspace_id   = module.monitor.log_analytics_workspace_id
  }
  sensitive = false
}