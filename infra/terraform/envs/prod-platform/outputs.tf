# Platform Layer Outputs
# These outputs are consumed by downstream layers via remote state

# Container Apps Environment
output "container_app_environment_id" {
  description = "ID of the Container Apps Environment"
  value       = module.aca_env.container_app_environment_id
}

output "static_ip" {
  description = "Static IP address of the Container Apps Environment internal load balancer"
  value       = module.aca_env.static_ip
}

output "default_domain" {
  description = "Default domain of the Container Apps Environment"
  value       = module.aca_env.default_domain
}

output "workload_profile_name" {
  description = "Name of the workload profile"
  value       = var.aca_workload_profile.name
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone for the Container Apps Environment"
  value       = module.aca_env.private_dns_zone_id
}