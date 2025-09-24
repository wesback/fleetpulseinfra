variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "fleetpulse"
}

# Backend configuration for remote state
variable "backend_rg" {
  description = "Resource group name for Terraform backend"
  type        = string
  default     = "rg-terraform-state-prod"
}

variable "backend_sa" {
  description = "Storage account name for Terraform backend"
  type        = string
  default     = "stwbtfstateprod"
}

variable "backend_container" {
  description = "Container name for Terraform backend"
  type        = string
  default     = "tfstate"
}

# Custom Domains
variable "custom_domains" {
  description = "Custom domains for applications"
  type = object({
    backend  = string
    frontend = string
    wildcard = string
  })
  default = {
    backend  = "backend.backelant.eu"
    frontend = "frontend.backelant.eu"
    wildcard = "*.backelant.eu"
  }
}

# Resource Sizing
variable "aca_workload_profile" {
  description = "ACA workload profile configuration"
  type = object({
    name                  = string
    workload_profile_type = string
    minimum_count         = number
    maximum_count         = number
  })
  default = {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 10
  }
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "prod"
    Project     = "fleetpulse"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}