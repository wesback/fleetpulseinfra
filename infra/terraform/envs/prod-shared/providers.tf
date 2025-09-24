terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.44.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1.0"
    }
  }

  backend "azurerm" {
    # Backend configuration will be provided via backend config file or CLI
    # Example:
    # resource_group_name   = "rg-terraform-state-prod"
    # storage_account_name  = "stwbtfstateprod"
    # container_name        = "tfstate"
    key = "prod-shared.tfstate"
    # use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azapi" {}

provider "random" {}