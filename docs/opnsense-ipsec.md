# OPNsense IPsec Configuration for Azure VPN

This guide provides step-by-step instructions for configuring OPNsense to establish a Site-to-Site IPsec VPN connection with Azure Virtual Network Gateway.

## Prerequisites

- OPNsense firewall with public IP address
- Admin access to OPNsense web interface
- Azure VPN Gateway deployed (from Terraform)
- Pre-shared key (PSK) from `terraform.tfvars`
- Important: treat the PSK and any public IPs as sensitive. Do NOT commit them to the repository. Store them in a secrets store (GitHub Actions Secrets, or Azure Key Vault) and inject them into CI (this repo's workflow injects `TF_VAR_vpn_shared_key`).

## Phase 1 (IKE) Configuration

### 1. Navigate to VPN > IPsec > Connections

1. Go to **VPN → IPsec → Connections**
2. Click the **[+]** button to add a new connection
3. Configure the General settings as shown below

Create a new connection with these **General settings**:

| Setting | Value | Notes |
|---------|-------|-------|
| **enabled** | ✓ (checked) | Enable the connection |
| **Proposals** | default | Use default proposal set |
| **Version** | IKEv1+IKEv2 | Azure VPN Gateway supports both |
| **MOBIKE** | ✓ (checked) | Enable mobility and multihoming |
| **Local addresses** | (leave empty) | Auto-detect WAN interface |
| **Remote addresses** | `<AZURE_VPN_GATEWAY_IP>` | From Terraform output |
| **DPD delay (s)** | 10 | Dead Peer Detection interval |
| **Pools** | Nothing selected | Not needed for site-to-site |
| **Description** | Azure FleetPulse VPN | |

### 2. Configure Authentication and Child SAs

After saving the General settings above, you'll need to configure:

1. **Local Authentication** - Click on the connection entry to edit it further
2. **Remote Authentication** - Set the pre-shared key
3. **Child SAs** - Configure the traffic selectors (equivalent to Phase 2)

**Authentication Settings:**
- **Authentication Method**: Pre-shared Key (PSK)
- **Pre-Shared Key**: `<YOUR_PSK>` (Sensitive — retrieve from secret store, do not paste into source files)
- **Local/Remote Identifiers**: Use IP addresses for static IPs, or FQDN/Distinguished Name for dynamic IPs

**Important Notes:**
- The "Proposals" dropdown uses predefined algorithm sets. The "default" proposal includes AES-256, SHA256, and appropriate DH groups that are compatible with Azure VPN Gateway.
- If your OPNsense public IP is dynamic or behind NAT, enable MOBIKE and use appropriate identifier types (FQDN or defined Peer ID) rather than IP addresses.
- AES-GCM (authenticated encryption) is included in modern proposal sets when both peers support it.

NAT and Identifier guidance

- If your OPNsense public IP is dynamic or behind NAT, do not rely solely on IP address identifiers. Use appropriate Identifier types (FQDN or defined Peer ID) and enable NAT-Traversal (NAT-T). Mismatched identifiers are a common cause of silent authentication failures.

## Child SA (Traffic Selectors) Configuration

### 1. Configure Child SAs for Traffic Routing

In the connection entry, you need to define Child SAs (Security Associations) that specify which traffic should use the VPN:

1. Click on your connection entry to edit it
2. Look for "Children" or "Child SAs" section
3. Add a new child SA with these settings:

**Child SA Settings:**
| Setting | Value | Notes |
|---------|-------|-------|
| **Local Traffic Selector** | `192.168.0.0/24` | Your on-premises network CIDR |
| **Remote Traffic Selector** | `10.20.0.0/24` | Azure VNET CIDR from terraform.tfvars |
| **Mode** | Tunnel | Standard for site-to-site VPN |
| **Protocol** | ESP | Encapsulating Security Payload |

**Important Notes:**
- Azure VPN Gateways are route-based. The traffic selectors define which networks can communicate over the VPN.
- Local traffic selector = your on-premises network (behind OPNsense)
- Remote traffic selector = Azure VNET CIDR (must match exactly what's configured in Terraform)
- The connection will use the default ESP proposals which include AES-256, SHA256, and appropriate PFS groups

## Firewall Rules Configuration

### 1. IPsec Interface Rules

Navigate to **Firewall > Rules > IPsec**:

```
Action: Pass
Interface: IPsec
Direction: in
TCP/IP Version: IPv4
Protocol: any
Source: 10.20.0.0/24 (Azure VNET)
Destination: 192.168.0.0/24 (On-premises)
Description: Allow Azure to On-premises
```

```
Action: Pass
Interface: IPsec
Direction: in
TCP/IP Version: IPv4
Protocol: any
Source: 192.168.0.0/24 (On-premises)
Destination: 10.20.0.0/24 (Azure VNET)
Description: Allow On-premises to Azure
```

### 2. WAN Interface Rules

Navigate to **Firewall > Rules > WAN**:

```
Action: Pass
Interface: WAN
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: <AZURE_VPN_GATEWAY_IP>
Source Port: any
Destination: WAN address
Destination Port: 500 (IKE)
Description: Allow IKE from Azure
```

```
Action: Pass
Interface: WAN
Direction: in
TCP/IP Version: IPv4
Protocol: UDP
Source: <AZURE_VPN_GATEWAY_IP>
Source Port: any
Destination: WAN address
Destination Port: 4500 (NAT-T)
Description: Allow NAT-T from Azure
```

### 3. LAN Interface Rules

Navigate to **Firewall > Rules > LAN**:

```
Action: Pass
Interface: LAN
Direction: in
TCP/IP Version: IPv4
Protocol: any
Source: LAN net
Destination: 10.20.0.0/24 (Azure VNET)
Description: Allow LAN to Azure
```

## Static Routes Configuration

Navigate to **System > Routes > Configuration**:

Add route to Azure networks:

| Setting | Value |
|---------|-------|
| **Network Address** | `10.20.0.0/24` |
| **Gateway** | `<VPN_GATEWAY_INTERFACE>` |
| **Description** | Route to Azure FleetPulse VNET |

## NAT Configuration (if required)

If you need to NAT traffic to Azure, navigate to **Firewall > NAT > Outbound**:

```
Interface: IPsec
Source: 192.168.0.0/24
Destination: 10.20.0.0/24
Translation: Interface address
Description: NAT for Azure traffic
```

## Verification and Troubleshooting

### 1. Check VPN Status

Navigate to **VPN > IPsec > Status Overview**:

- Phase 1 should show "ESTABLISHED"
- Phase 2 should show "INSTALLED"

Quick CLI checks (useful when the UI is unavailable or for automation):

```bash
# Show status summary
configctl ipsec status

# Show full strongSwan status
ipsec statusall

# Show SAs and lifetimes
ipsec listall
```

Quick verification checklist:

- Phase1 state: ESTABLISHED
- Phase2 state: INSTALLED
- Correct SA lifetimes and matching proposals
- Ping an Azure VNET address (e.g. 10.20.0.4) from on‑prem
- Verify DNS resolution if DNS forwarding is configured

Troubleshooting: Can't find the IPsec Connections page?

- Ensure you are logged in as an admin user — non‑privileged accounts may hide menu items.
- Use the UI sidebar search (type "IPsec" or "VPN") to jump directly to the IPsec page.
- The correct path is VPN → IPsec → **Connections** (this is the standard location in modern OPNsense versions).
- If the page is blank or controls are greyed out, clear your browser cache or try a different browser and confirm the ipsec service is running (see CLI checks above).

### 2. Test Connectivity

From OPNsense CLI or a client behind OPNsense:

```bash
# Test basic connectivity to Azure VNET
ping 10.20.0.4

# Test DNS resolution (if DNS forwarding is configured)
nslookup backend.backelant.eu

# Test application connectivity
curl -k https://backend.backelant.eu:8000/health
```

### 3. Common Issues and Solutions

#### Issue: Phase 1 fails to establish

**Symptoms**: Status shows "CONNECTING" or authentication errors

**Solutions**:
1. Verify pre-shared key matches on both sides
2. Check firewall rules allow UDP 500 and 4500
3. Verify public IP addresses are correct
4. Check Azure VPN Gateway status in Azure portal

#### Issue: Phase 2 fails to install

**Symptoms**: Phase 1 established but no Phase 2

**Solutions**:
1. Verify network configurations match
2. Check that interesting traffic is defined correctly
3. Ensure PFS groups match on both sides
4. Verify lifetime settings are compatible

#### Issue: Traffic not flowing

**Symptoms**: VPN connected but no traffic

**Solutions**:
1. Check IPsec firewall rules
2. Verify static routes are configured
3. Check NAT rules if required
4. Verify Azure NSG rules allow traffic

### 4. Monitoring and Logs

Monitor VPN status and troubleshoot issues:

1. **IPsec Status**: VPN > IPsec > Status Overview
2. **System Logs**: System > Log Files > System
3. **Firewall Logs**: Firewall > Log Files > Live View
4. **IPsec Logs**: VPN > IPsec > Log File

### 5. Performance Tuning

For optimal performance:

```bash
# Enable hardware crypto acceleration if available
# System > Advanced > Miscellaneous
# Check "Use hardware crypto"

# Adjust MTU if fragmentation issues occur
# VPN > IPsec > Advanced Settings
# Set maximum MSS to 1436
```

## Integration with Technitium DNS

Once the VPN is established, configure DNS forwarding:

1. In OPNsense, navigate to **System > Settings > General**
2. Add Azure DNS Private Resolver IP as a DNS server: `10.20.0.132`
3. Configure conditional forwarding in Technitium (see `technitium-dns.md`)

## Security Best Practices

1. **Regular PSK Rotation**: Change pre-shared keys quarterly
2. **Monitoring**: Set up alerts for VPN disconnections
3. **Access Control**: Limit which on-premises networks can access Azure
4. **Logging**: Enable comprehensive logging for security auditing
5. **Updates**: Keep OPNsense updated with latest security patches

## Configuration Backup

Always backup your OPNsense configuration:

1. Navigate to **System > Configuration > Backups**
2. Create a backup before making changes
3. Store backups securely off-site
4. Test restore procedures regularly

## Example CLI Configuration

For scripted deployment, here's the equivalent CLI configuration:

```bash
# Create Phase 1
configctl ipsec phase1 add \
  --interface=wan \
  --remote-gateway=<AZURE_VPN_GATEWAY_IP> \
  --authentication-method=pre_shared_key \
  --psk=<YOUR_PSK> \
  --ike-version=ikev2 \
  --encryption=aes256 \
  --hash=sha256 \
  --dhgroup=14 \
  --lifetime=28800

# Create Phase 2
configctl ipsec phase2 add \
  --phase1-id=<PHASE1_ID> \
  --local-subnet=192.168.0.0/24 \
  --remote-subnet=10.20.0.0/24 \
  --protocol=esp \
  --encryption=aes256 \
  --hash=sha256 \
  --pfsgroup=14 \
  --lifetime=27000

# Apply configuration
configctl ipsec reload
```

## Support and Documentation

- [OPNsense IPsec Documentation](https://docs.opnsense.org/manual/ipsec.html)
- [Azure VPN Gateway Documentation](https://docs.microsoft.com/en-us/azure/vpn-gateway/)
- Community support: OPNsense Forum and Reddit