# Apps Layer Outputs
# These outputs provide essential information for DNS configuration and validation

output "container_app_environment_static_ip" {
  description = "Static IP address of the Container App Environment (Internal Load Balancer)"
  value       = data.terraform_remote_state.platform.outputs.static_ip
}

output "container_app_environment_default_domain" {
  description = "Default domain suffix of the Container App Environment"
  value       = data.terraform_remote_state.platform.outputs.default_domain
}

output "dns_resolver_inbound_ip" {
  description = "Inbound IP address of the DNS Private Resolver for on-premises conditional forwarding"
  value       = data.terraform_remote_state.network.outputs.dns_resolver_inbound_ip
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway for OPNsense configuration"
  value       = data.terraform_remote_state.network.outputs.vpn_gateway_public_ip
}

output "storage_account_name" {
  description = "Name of the Azure Storage Account for Azure Files"
  value       = data.terraform_remote_state.shared.outputs.storage_account_name
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = data.terraform_remote_state.shared.outputs.key_vault_name
}

output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = data.terraform_remote_state.shared.outputs.application_insights_name
}

# DNS Configuration Information
output "dns_configuration" {
  description = "DNS configuration information for on-premises setup"
  value = {
    # Add these A records to Technitium DNS
    a_records = {
      (var.custom_domains.backend)  = data.terraform_remote_state.platform.outputs.static_ip
      (var.custom_domains.frontend) = data.terraform_remote_state.platform.outputs.static_ip
    }

    # Configure these conditional forwarders to DNS Resolver inbound IP
    conditional_forwarders = {
      "privatelink.vaultcore.azure.net"   = data.terraform_remote_state.network.outputs.dns_resolver_inbound_ip
      "privatelink.file.core.windows.net" = data.terraform_remote_state.network.outputs.dns_resolver_inbound_ip
      "privatelink.monitor.azure.com"     = data.terraform_remote_state.network.outputs.dns_resolver_inbound_ip
    }

    # Wildcard DNS zone for Container App Environment
    wildcard_zone = {
      zone = data.terraform_remote_state.platform.outputs.default_domain
      ip   = data.terraform_remote_state.platform.outputs.static_ip
    }
  }
}

# Resource IDs for CI/CD reference
output "resource_ids" {
  description = "Resource IDs for CI/CD pipelines"
  value = {
    resource_group_id            = data.terraform_remote_state.network.outputs.resource_group_id
    container_app_environment_id = data.terraform_remote_state.platform.outputs.container_app_environment_id
    key_vault_id                 = data.terraform_remote_state.shared.outputs.key_vault_id
    storage_account_id           = data.terraform_remote_state.shared.outputs.storage_account_id
    log_analytics_workspace_id   = data.terraform_remote_state.shared.outputs.log_analytics_workspace_id
  }
  sensitive = false
}