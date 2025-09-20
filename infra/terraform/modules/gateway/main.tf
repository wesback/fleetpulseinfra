# VPN Gateway Module
# Creates Site-to-Site VPN connection to OPNsense router

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "${var.name_prefix}-vpngw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Virtual Network Gateway (VPN)
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "${var.name_prefix}-vpngw"
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = false
  sku                 = var.vpn_gateway_sku
  tags                = var.tags

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }
}

# Local Network Gateway (represents on-premises OPNsense)
resource "azurerm_local_network_gateway" "opnsense" {
  name                = "${var.name_prefix}-lng-opnsense"
  location            = var.location
  resource_group_name = var.resource_group_name
  gateway_address     = var.on_premises_gateway_ip
  address_space       = var.on_premises_networks
  tags                = var.tags
}

# Site-to-Site VPN Connection
resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                = "${var.name_prefix}-vpn-s2s"
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "IPsec"
  
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.opnsense.id
  shared_key                 = var.vpn_shared_key
  
  # IKEv2 settings compatible with OPNsense
  connection_protocol = "IKEv2"
  
  # IPSec Policy for compatibility with OPNsense
  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS14"
    sa_datasize      = 102400000
    sa_lifetime      = 27000
  }
  
  tags = var.tags
}