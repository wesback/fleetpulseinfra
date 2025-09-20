variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "gateway_subnet_id" {
  description = "ID of the Gateway subnet"
  type        = string
}

variable "vpn_gateway_sku" {
  description = "SKU for VPN Gateway"
  type        = string
  default     = "VpnGw1"
}

variable "on_premises_gateway_ip" {
  description = "Public IP of on-premises OPNsense gateway"
  type        = string
}

variable "on_premises_networks" {
  description = "On-premises network CIDRs"
  type        = list(string)
}

variable "vpn_shared_key" {
  description = "Pre-shared key for VPN connection"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}