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

# Container Images
variable "container_images" {
  description = "Container images for applications"
  type = object({
    backend  = string
    frontend = string
    otel     = string
  })
  default = {
    backend  = "wesback/fleetpulse-backend:latest"
    frontend = "wesback/fleetpulse-frontend:latest"
    otel     = "otel/opentelemetry-collector-contrib:0.91.0"
  }
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

variable "home_cidrs" {
  description = "Home network CIDRs for IP restrictions"
  type        = list(string)
  default     = ["192.168.0.0/24"] # TODO: Replace with actual home network CIDRs
}

variable "app_resources" {
  description = "Resource configuration for applications"
  type = object({
    backend = object({
      cpu    = number
      memory = string
    })
    frontend = object({
      cpu    = number
      memory = string
    })
    otel = object({
      cpu    = number
      memory = string
    })
  })
  default = {
    backend = {
      cpu    = 0.5
      memory = "1Gi"
    }
    frontend = {
      cpu    = 0.25
      memory = "0.5Gi"
    }
    otel = {
      cpu    = 0.25
      memory = "0.5Gi"
    }
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