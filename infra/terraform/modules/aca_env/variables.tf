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

variable "aca_subnet_id" {
  description = "ID of the Container Apps subnet"
  type        = string
}

variable "vnet_id" {
  description = "ID of the virtual network for DNS zone linking"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  type        = string
}

variable "workload_profile" {
  description = "ACA workload profile configuration"
  type = object({
    name                    = string
    workload_profile_type   = string
    minimum_count          = number
    maximum_count          = number
  })
}

variable "custom_domains" {
  description = "Custom domains for applications"
  type = object({
    backend   = string
    frontend  = string
    wildcard  = string
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}