# Terraform Backend Configuration
# 
# For production, consider using remote state with private endpoints and encryption.
# Example Azure Storage backend configuration:
#
# terraform {
#   backend "azurerm" {
#     resource_group_name   = "rg-terraform-state-prod"
#     storage_account_name  = "stwbtfstateprod"     # TODO: Update with actual storage account
#     container_name        = "tfstate"
#     key                   = "fleetpulse/prod.tfstate"
#     use_azuread_auth     = true
#     # Optional: Use private endpoint for state storage
#     # use_msi              = true
#   }
# }
#
# To set up remote state:
# 1. Create a storage account with private endpoint
# 2. Enable versioning and soft delete
# 3. Configure RBAC for CI/CD identity
# 4. Initialize: terraform init -backend-config=backend.conf
#
# For initial setup, local state is used (not recommended for production)