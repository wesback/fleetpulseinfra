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

variable "manage_placeholder_secrets" {
  description = "Whether the module should create placeholder certificate secrets (requires data-plane network access). Leave false for initial deployment when running Terraform from outside the private network."
  type        = bool
  default     = false
}