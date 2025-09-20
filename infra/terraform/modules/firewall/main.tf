# Azure Firewall Module
# Creates Azure Firewall with UDR to control egress traffic from ACA

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "${var.name_prefix}-fw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Azure Firewall Policy
resource "azurerm_firewall_policy" "main" {
  name                = "${var.name_prefix}-fw-policy"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags
}

# Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "DefaultRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 500

  # Network Rules - Allow essential Azure services
  network_rule_collection {
    name     = "AllowAzureServices"
    priority = 400
    action   = "Allow"

    # Allow DNS
    rule {
      name                  = "AllowDNS"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["168.63.129.16"]
      destination_ports     = ["53"]
    }

    # Allow NTP
    rule {
      name                  = "AllowNTP"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }

    # Allow HTTP/HTTPS for container pulls and updates
    rule {
      name                  = "AllowHTTP"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["80", "443"]
    }
  }

  # Application Rules - Allow specific FQDNs
  application_rule_collection {
    name     = "AllowContainerServices"
    priority = 500
    action   = "Allow"

    # Allow Docker Hub
    rule {
      name = "AllowDockerHub"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = ["*"]
      destination_fqdns = [
        "*.docker.io",
        "*.docker.com",
        "production.cloudflare.docker.com",
        "registry-1.docker.io"
      ]
    }

    # Allow Azure services
    rule {
      name = "AllowAzureServices"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = ["*"]
      destination_fqdns = [
        "*.core.windows.net",
        "*.vault.azure.net",
        "*.monitor.azure.com",
        "*.applicationinsights.azure.com",
        "login.microsoftonline.com",
        "management.azure.com"
      ]
    }
  }
}

# Azure Firewall
resource "azurerm_firewall" "main" {
  name                = "${var.name_prefix}-fw"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main.id
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# Route Table for ACA subnet
resource "azurerm_route_table" "aca" {
  name                = "${var.name_prefix}-rt-aca"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Route all traffic through Azure Firewall
  route {
    name           = "DefaultRouteToFirewall"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }

  # Route on-premises traffic directly (bypass firewall for internal traffic)
  dynamic "route" {
    for_each = var.on_premises_networks
    content {
      name           = "OnPremisesRoute${route.key}"
      address_prefix = route.value
      next_hop_type  = "VirtualNetworkGateway"
    }
  }
}

# Associate route table with ACA subnet
resource "azurerm_subnet_route_table_association" "aca" {
  subnet_id      = var.aca_subnet_id
  route_table_id = azurerm_route_table.aca.id
}