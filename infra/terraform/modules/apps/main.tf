# Container Apps Module
# Creates the FleetPulse applications: backend, frontend, and OpenTelemetry collector

# Get curre    }
  }

  # Secret for Application Insights connection string from Key Vault - conditional
  dynamic "secret" {
    for_each = var.application_insights_connection_string_secret_uri != null ? [1] : []
    content {
      name                = "app-insights-connection-string"
      key_vault_secret_id = var.application_insights_connection_string_secret_uri
      identity            = azurerm_user_assigned_identity.apps.id
    }
  }
}

# Backend Container Appnfiguration for managed identity
data "azurerm_client_config" "current" {}

# User-assigned managed identity for Container Apps
resource "azurerm_user_assigned_identity" "apps" {
  name                = "${var.name_prefix}-apps-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Role assignment for Key Vault access
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.apps.principal_id
}

# OpenTelemetry Collector Container App
resource "azurerm_container_app" "otel_collector" {
  name                         = "${var.name_prefix}-otel-collector"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode               = "Single"
  workload_profile_name       = var.workload_profile_name
  tags                        = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps.id]
  }

  template {
    container {
      name   = "otel-collector"
      image  = var.container_images.otel
      cpu    = var.app_resources.otel.cpu
      memory = var.app_resources.otel.memory

      # Standard OpenTelemetry environment variables - conditional based on secret availability
      dynamic "env" {
        for_each = var.application_insights_connection_string_secret_uri != null ? [1] : []
        content {
          name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
          secret_name = "app-insights-connection-string"
        }
      }

      # Alternative: Direct connection string when not using Key Vault
      dynamic "env" {
        for_each = var.application_insights_connection_string_secret_uri == null && var.application_insights_connection_string != null ? [1] : []
        content {
          name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
          value = var.application_insights_connection_string
        }
      }

      # Basic OTEL Collector configuration
      env {
        name  = "OTEL_COLLECTOR_CONFIG_YAML"
        value = base64encode(yamlencode({
          receivers = {
            otlp = {
              protocols = {
                grpc = {
                  endpoint = "0.0.0.0:4317"
                }
                http = {
                  endpoint = "0.0.0.0:4318"
                }
              }
            }
          }
          processors = {
            batch = {}
          }
          exporters = {
            azuremonitor = {
              connection_string = "$${APPLICATIONINSIGHTS_CONNECTION_STRING}"
            }
          }
          service = {
            pipelines = {
              traces = {
                receivers = ["otlp"]
                processors = ["batch"]
                exporters = ["azuremonitor"]
              }
              metrics = {
                receivers = ["otlp"]
                processors = ["batch"]
                exporters = ["azuremonitor"]
              }
              logs = {
                receivers = ["otlp"]
                processors = ["batch"]
                exporters = ["azuremonitor"]
              }
            }
          }
        }))
      }
    }

    min_replicas = 1
    max_replicas = 2
  }

  # Internal ingress for OTLP endpoints
  ingress {
    allow_insecure_connections = true # Internal only, TLS termination at load balancer
    external_enabled          = false
    target_port               = 4317
    transport                 = "tcp"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    # Restrict access to home networks
    dynamic "ip_security_restriction" {
      for_each = var.home_cidrs
      content {
        name             = "AllowHome${ip_security_restriction.key}"
        ip_address_range = ip_security_restriction.value
        action           = "Allow"
      }
    }
  }

  # Secret for Application Insights connection string from Key Vault
  secret {
    name                = "app-insights-connection-string"
    key_vault_secret_id = var.application_insights_connection_string_secret_uri
    identity            = azurerm_user_assigned_identity.apps.id
  }
}

# Backend Container App
resource "azurerm_container_app" "backend" {
  name                         = "${var.name_prefix}-backend"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode               = "Single"
  workload_profile_name       = var.workload_profile_name
  tags                        = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps.id]
  }

  template {
    container {
      name   = "backend"
      image  = var.container_images.backend
      cpu    = var.app_resources.backend.cpu
      memory = var.app_resources.backend.memory

      env {
        name  = "FLEETPULSE_DATA_DIR"
        value = "/data"
      }

      env {
        name  = "DEPLOYMENT_MODE"
        value = "uvicorn"
      }

      # Standard OpenTelemetry environment variables
      env {
        name  = "OTEL_RESOURCE_ATTRIBUTES"
        value = "service.name=fleetpulse-backend,service.version=1.0.0,deployment.environment=prod"
      }

      env {
        name  = "OTEL_TRACES_SAMPLER"
        value = "parentbased_traceidratio"
      }

      env {
        name  = "OTEL_TRACES_SAMPLER_ARG"
        value = "1.0"
      }

      env {
        name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
        value = "grpc"
      }

      env {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://otel-collector.${var.container_app_environment_domain}:4317"
      }

      # Volume mount for Azure Files (configured via post-deploy script)
      volume_mounts {
        name = "data-volume"
        path = "/data"
      }
    }

    # Volume for Azure Files (will be configured by post-deploy script)
    volume {
      name         = "data-volume"
      storage_type = "AzureFile"
      storage_name = "files" # This storage will be created by post-deploy script
    }

    min_replicas = 1
    max_replicas = 3
  }

  # Internal HTTPS ingress
  ingress {
    allow_insecure_connections = true # Internal only, TLS termination at load balancer
    external_enabled          = false
    target_port               = 8000
    transport                 = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    # Restrict access to home networks
    dynamic "ip_security_restriction" {
      for_each = var.home_cidrs
      content {
        name             = "AllowHome${ip_security_restriction.key}"
        ip_address_range = ip_security_restriction.value
        action           = "Allow"
      }
    }
  }

  # Secret for Application Insights connection string from Key Vault - conditional
  dynamic "secret" {
    for_each = var.application_insights_connection_string_secret_uri != null ? [1] : []
    content {
      name                = "app-insights-connection-string"
      key_vault_secret_id = var.application_insights_connection_string_secret_uri
      identity            = azurerm_user_assigned_identity.apps.id
    }
  }
}

# Frontend Container App
resource "azurerm_container_app" "frontend" {
  name                         = "${var.name_prefix}-frontend"
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode               = "Single"
  workload_profile_name       = var.workload_profile_name
  tags                        = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.apps.id]
  }

  template {
    container {
      name   = "frontend"
      image  = var.container_images.frontend
      cpu    = var.app_resources.frontend.cpu
      memory = var.app_resources.frontend.memory
    }

    min_replicas = 1
    max_replicas = 2
  }

  # Internal HTTPS ingress
  ingress {
    allow_insecure_connections = true # Internal only, TLS termination at load balancer
    external_enabled          = false
    target_port               = 80
    transport                 = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    # Restrict access to home networks
    dynamic "ip_security_restriction" {
      for_each = var.home_cidrs
      content {
        name             = "AllowHome${ip_security_restriction.key}"
        ip_address_range = ip_security_restriction.value
        action           = "Allow"
      }
    }
  }
}

# Note: Custom domain binding and certificate management will be handled by post-deploy scripts
# This avoids storing PFX certificate content in Terraform state