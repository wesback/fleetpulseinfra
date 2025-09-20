output "policy_assignment_id" {
  description = "ID of the Container Apps policy assignment"
  value       = azurerm_resource_group_policy_assignment.container_apps_no_external.id
}