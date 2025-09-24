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

variable "vnet_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "privatelink_subnet_id" {
  description = "ID of the private link subnet"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "shared_access_key_enabled" {
  description = "Shared key authentication flag. Must remain disabled because Azure Policy blocks storage account keys."
  type        = bool
  default     = false

  validation {
    condition     = var.shared_access_key_enabled == false
    error_message = "Shared key authentication is prohibited by policy. Use Azure AD (OAuth) authentication instead."
  }
}

variable "default_to_oauth_authentication" {
  description = "Whether to default data-plane requests to use Azure AD (OAuth) authentication."
  type        = bool
  default     = false
}

variable "create_storage_share" {
  description = "Controls whether an Azure Files share is created."
  type        = bool
  default     = true
}

variable "storage_share_name" {
  description = "Name of the Azure Files share to create when enabled."
  type        = string
  default     = "fleetpulse"
}

variable "storage_share_quota_gb" {
  description = "Quota in GB for the Azure Files share."
  type        = number
  default     = 100
}