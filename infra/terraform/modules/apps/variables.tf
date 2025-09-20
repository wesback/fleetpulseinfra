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

variable "container_app_environment_id" {
  description = "ID of the Container Apps Environment"
  type        = string
}

variable "container_app_environment_domain" {
  description = "Default domain of the Container Apps Environment"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault"
  type        = string
}

variable "application_insights_connection_string_secret_uri" {
  description = "Key Vault secret URI for Application Insights connection string"
  type        = string
}

variable "container_images" {
  description = "Container images for applications"
  type = object({
    backend   = string
    frontend  = string
    otel      = string
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

variable "home_cidrs" {
  description = "Home network CIDRs for IP restrictions"
  type        = list(string)
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
}

variable "workload_profile_name" {
  description = "Name of the workload profile"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}