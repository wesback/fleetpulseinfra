# Policy Module
# Applies Azure Policy to enforce Container Apps security requirements

# Get the built-in policy definition for Container Apps external network access
data "azurerm_policy_definition" "container_apps_external_network" {
  display_name = "Container Apps should disable external network access"
}

# Assign the policy to the resource group
resource "azurerm_resource_group_policy_assignment" "container_apps_no_external" {
  name                 = "deny-container-apps-external-access"
  resource_group_id    = var.resource_group_id
  policy_definition_id = data.azurerm_policy_definition.container_apps_external_network.id
  display_name         = "Deny Container Apps External Network Access"
  description          = "This policy ensures that Container Apps cannot be configured with external network access enabled"
  enforce              = true
}