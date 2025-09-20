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

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "firewall_subnet_id" {
  description = "ID of the Azure Firewall subnet"
  type        = string
}

variable "aca_subnet_id" {
  description = "ID of the Container Apps subnet"
  type        = string
}

variable "on_premises_networks" {
  description = "On-premises network CIDRs for routing"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}