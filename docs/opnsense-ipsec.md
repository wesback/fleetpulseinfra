# OPNsense IPsec Configuration for Azure VPN

This guide provides step-by-step instructions for configuring OPNsense to establish a Site-to-Site IPsec VPN connection with Azure Virtual Network Gateway.

## Prerequisites

- OPNsense firewall with public IP address
- Admin access to OPNsense web interface
- Azure VPN Gateway deployed (from Terraform)
- Pre-shared key (PSK) from `terraform.tfvars`

## Phase 1 (IKE) Configuration

### 1. Navigate to VPN > IPsec > Tunnel Settings

Create a new Phase 1 configuration with these settings:

| Setting | Value | Notes |
|---------|-------|-------|
| **Connection Method** | Start on traffic | |
| **Key Exchange Version** | IKEv2 | Azure VPN Gateway requirement |
| **Internet Protocol** | IPv4 | |
| **Interface** | WAN | Your internet-facing interface |
| **Remote Gateway** | `<AZURE_VPN_GATEWAY_IP>` | From Terraform output |
| **Description** | Azure FleetPulse VPN | |

### 2. Phase 1 Proposal (Authentication)

| Setting | Value | Notes |
|---------|-------|-------|
| **Authentication Method** | Mutual PSK | |
| **My Identifier** | My IP Address | |
| **Peer Identifier** | Peer IP Address | |
| **Pre-Shared Key** | `<YOUR_PSK>` | From terraform.tfvars |

### 3. Phase 1 Proposal (Algorithms)

| Setting | Value | Notes |
|---------|-------|-------|
| **Encryption Algorithm** | AES 256 | |
| **Hash Algorithm** | SHA256 | |
| **DH Group** | 14 (2048 bit) | |
| **Lifetime** | 28800 | 8 hours (Azure default) |

### 4. Advanced Options

| Setting | Value | Notes |
|---------|-------|-------|
| **Dead Peer Detection** | Enabled | |
| **DPD Delay** | 10 | seconds |
| **DPD Max Failures** | 5 | |

## Phase 2 (IPsec) Configuration

### 1. Create Phase 2 Entry

Click "Show Phase 2 Entries" and add a new entry:

| Setting | Value | Notes |
|---------|-------|-------|
| **Mode** | Tunnel IPv4 | |
| **Description** | Azure FleetPulse Traffic | |

### 2. Local Network

| Setting | Value | Notes |
|---------|-------|-------|
| **Local Network** | Network | |
| **Address** | `192.168.0.0` | Your on-premises network |
| **Netmask** | `24` | Adjust as needed |

### 3. Remote Network

| Setting | Value | Notes |
|---------|-------|-------|
| **Remote Network** | Network | |
| **Address** | `10.20.0.0` | Azure VNET CIDR |
| **Netmask** | `24` | From terraform.tfvars |

### 4. Phase 2 Proposal (Algorithms)

| Setting | Value | Notes |
|---------|-------|-------|
| **Protocol** | ESP | |
| **Encryption Algorithms** | AES 256 | |
| **Hash Algorithms** | SHA256 | |
| **PFS Group** | 14 (2048 bit) | Perfect Forward Secrecy |
| **Lifetime** | 27000 | seconds (7.5 hours) |

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

## Maintenance Schedule

Recommended maintenance tasks:

- **Weekly**: Check VPN status and logs
- **Monthly**: Review firewall rules and logs
- **Quarterly**: Update PSK and test failover
- **Annually**: Full configuration review and documentation update