variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-fleetpulse-prod"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West Europe"
}

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

# Networking
variable "vnet_cidr" {
  description = "CIDR block for the virtual network"
  type        = string
  default     = "10.20.0.0/24"
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type = object({
    aca_infra            = string
    gateway              = string
    privatelink          = string
    # firewall             = string  # Removed for cost optimization
    dns_resolver_inbound = string
  })
  default = {
    aca_infra            = "10.20.0.0/27"   # 30 IPs
    gateway              = "10.20.0.32/27"  # 30 IPs (GatewaySubnet)
    privatelink          = "10.20.0.64/27"  # 30 IPs
    # firewall             = "10.20.0.96/27"  # 30 IPs (Reserved for future firewall)
    dns_resolver_inbound = "10.20.0.128/27" # 30 IPs
  }
}

variable "home_cidrs" {
  description = "Home network CIDRs for IP restrictions"
  type        = list(string)
  default     = ["192.168.0.0/24"] # TODO: Replace with actual home network CIDRs
}

# VPN Configuration
variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway"
  type        = string
  default     = "VpnGw1"
}

variable "on_premises_gateway_ip" {
  description = "Public IP of on-premises OPNsense gateway"
  type        = string
  default     = "203.0.113.1" # TODO: Replace with actual OPNsense public IP
}

variable "on_premises_networks" {
  description = "On-premises network CIDRs"
  type        = list(string)
  default     = ["192.168.0.0/24"] # TODO: Replace with actual on-premises CIDRs
}

variable "vpn_shared_key" {
  description = "Pre-shared key for VPN connection (should be stored in Key Vault)"
  type        = string
  sensitive   = true
  default     = "PLACEHOLDER-CHANGE-ME" # TODO: Set actual PSK in terraform.tfvars
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