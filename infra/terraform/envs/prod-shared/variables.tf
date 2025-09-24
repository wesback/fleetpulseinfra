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