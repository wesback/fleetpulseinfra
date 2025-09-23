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
    dns_resolver_inbound = string
  })
  default = {
    aca_infra            = "10.20.0.0/27"   # 30 IPs
    gateway              = "10.20.0.32/27"  # 30 IPs (GatewaySubnet)
    privatelink          = "10.20.0.64/27"  # 30 IPs
    dns_resolver_inbound = "10.20.0.128/27" # 30 IPs
  }
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