# Technitium DNS Configuration for FleetPulse Azure Integration

This guide provides step-by-step instructions for configuring Technitium DNS to support the FleetPulse Azure Container Apps deployment with private DNS resolution.

## Overview

The DNS configuration enables:
- Resolution of FleetPulse applications (`backend.backelant.eu`, `frontend.backelant.eu`) to Azure internal IPs
- Conditional forwarding of Azure private link domains to Azure DNS Private Resolver
- Seamless integration between on-premises and Azure resources

## Prerequisites

- Technitium DNS Server installed and running on your network
- Admin access to Technitium DNS web interface
- Azure infrastructure deployed (VPN connected)
- DNS Private Resolver inbound IP from Terraform output

## DNS Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ On-premises     │    │ Technitium DNS  │    │ Azure DNS       │
│ Clients         │ ─► │ Server          │ ─► │ Private Resolver│
│                 │    │                 │    │                 │
│ *.backelant.eu  │    │ Conditional     │    │ privatelink.*   │
│ queries         │    │ Forwarding      │    │ resolution      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Step 1: Configure Application A Records

### 1.1 Access Technitium DNS Web Interface

1. Open web browser and navigate to: `http://<TECHNITIUM_SERVER_IP>:5380`
2. Log in with administrator credentials

### 1.2 Create Zone (if not exists)

If `backelant.eu` zone doesn't exist:

1. Navigate to **Zones** tab
2. Click **Add Zone**
3. Configure:
   - **Zone Name**: `backelant.eu`
   - **Zone Type**: Primary Zone
   - **Dynamic Updates**: Disabled (for security)
4. Click **Add Zone**

### 1.3 Add A Records for FleetPulse Applications

Navigate to the `backelant.eu` zone and add these records:

#### Backend Application
1. Click **Add Record**
2. Configure:
   - **Name**: `backend`
   - **Type**: `A`
   - **TTL**: `300` (5 minutes)
   - **IPv4 Address**: `<ACA_STATIC_IP>` (from Terraform output)
   - **Comments**: `FleetPulse Backend - Azure Container Apps`
3. Click **Add Record**

#### Frontend Application
1. Click **Add Record**
2. Configure:
   - **Name**: `frontend`
   - **Type**: `A`
   - **TTL**: `300` (5 minutes)
   - **IPv4 Address**: `<ACA_STATIC_IP>` (from Terraform output)
   - **Comments**: `FleetPulse Frontend - Azure Container Apps`
3. Click **Add Record**

### 1.4 Verify A Records

Test the A records:
```bash
nslookup backend.backelant.eu <TECHNITIUM_SERVER_IP>
nslookup frontend.backelant.eu <TECHNITIUM_SERVER_IP>
```

Expected output:
```
Name:    backend.backelant.eu
Address: <ACA_STATIC_IP>
```

## Step 2: Configure Conditional Forwarders

### 2.1 Navigate to Settings

1. Click **Settings** tab
2. Select **Forwarders** from the left menu

### 2.2 Add Conditional Forwarders

Add the following conditional forwarders pointing to Azure DNS Private Resolver:

#### Key Vault Private Link
1. Click **Add Conditional Forwarder**
2. Configure:
   - **Domain**: `privatelink.vaultcore.azure.net`
   - **Forwarder Type**: `Default`
   - **Forwarder**: `<DNS_RESOLVER_INBOUND_IP>:53`
   - **Protocol**: `UDP`
   - **Comments**: `Azure Key Vault Private Link`
3. Click **Add**

#### Storage Account Private Link
1. Click **Add Conditional Forwarder**
2. Configure:
   - **Domain**: `privatelink.file.core.windows.net`
   - **Forwarder Type**: `Default`
   - **Forwarder**: `<DNS_RESOLVER_INBOUND_IP>:53`
   - **Protocol**: `UDP`
   - **Comments**: `Azure Storage Private Link`
3. Click **Add**

#### Application Insights Private Link
1. Click **Add Conditional Forwarder**
2. Configure:
   - **Domain**: `privatelink.monitor.azure.com`
   - **Forwarder Type**: `Default`
   - **Forwarder**: `<DNS_RESOLVER_INBOUND_IP>:53`
   - **Protocol**: `UDP`
   - **Comments**: `Azure Monitor Private Link`
3. Click **Add**

#### Additional Azure Monitor Domains
Add these additional forwarders for complete Azure Monitor functionality:

```
privatelink.oms.opinsights.azure.com → <DNS_RESOLVER_INBOUND_IP>:53
privatelink.ods.opinsights.azure.com → <DNS_RESOLVER_INBOUND_IP>:53  
privatelink.agentsvc.azure-automation.net → <DNS_RESOLVER_INBOUND_IP>:53
```

### 2.3 Configure Default Forwarders (Optional)

For internet resolution, configure default forwarders:

1. Under **Default Forwarders**, add:
   - `8.8.8.8` (Google DNS)
   - `1.1.1.1` (Cloudflare DNS)
   - `208.67.222.222` (OpenDNS)

## Step 3: Client Configuration

### 3.1 Update DHCP Server

Configure your DHCP server to provide Technitium DNS as the primary DNS server:

```
Primary DNS: <TECHNITIUM_SERVER_IP>
Secondary DNS: 8.8.8.8 (or your preferred backup)
```

### 3.2 Static Client Configuration

For static clients, update DNS settings:

**Windows:**
```cmd
netsh interface ipv4 set dns "Local Area Connection" static <TECHNITIUM_SERVER_IP>
netsh interface ipv4 add dns "Local Area Connection" 8.8.8.8 index=2
```

**Linux:**
```bash
# Update /etc/resolv.conf
echo "nameserver <TECHNITIUM_SERVER_IP>" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
```

## Step 4: Advanced Configuration

### 4.1 Access Control Lists (ACL)

Restrict DNS queries to authorized networks:

1. Navigate to **Settings > General**
2. Under **Access Control**, add:
   - **Allow**: `192.168.0.0/24` (your LAN)
   - **Allow**: `10.20.0.0/24` (Azure VNET)
   - **Deny**: `0.0.0.0/0` (everything else)

### 4.2 Query Logging

Enable query logging for troubleshooting:

1. Navigate to **Settings > Logging**
2. Enable **Query Logs**
3. Set **Max Log Days**: `7`
4. Click **Save**

### 4.3 Cache Settings

Optimize cache settings:

1. Navigate to **Settings > General**
2. Configure:
   - **DNS Cache**: Enabled
   - **Cache Max TTL**: `86400` (24 hours)
   - **Cache Min TTL**: `60` (1 minute)
   - **Cache Negative TTL**: `300` (5 minutes)

## Step 5: Validation and Testing

### 5.1 Test Application Resolution

From a client machine:

```bash
# Test FleetPulse applications
nslookup backend.backelant.eu
nslookup frontend.backelant.eu

# Expected result: <ACA_STATIC_IP>
```

### 5.2 Test Private Link Resolution

```bash
# Test Key Vault private link (replace with actual FQDN)
nslookup fleetpulse-prod-kv-123456.vault.azure.net

# Test Storage Account private link (replace with actual FQDN)  
nslookup fleetpulseprodst123456.file.core.windows.net

# Expected result: Private IP addresses (10.20.0.x)
```

### 5.3 Test End-to-End Connectivity

```bash
# Test HTTPS connectivity
curl -k https://backend.backelant.eu:8000/health
curl -k https://frontend.backelant.eu

# Test with verbose output for troubleshooting
curl -v -k https://backend.backelant.eu:8000/health
```

### 5.4 Monitor DNS Queries

1. Navigate to **Logs** tab in Technitium
2. Select **Query Logs**
3. Monitor for:
   - Successful resolution of FleetPulse domains
   - Conditional forwarding to Azure
   - Any NXDOMAIN responses (indicating issues)

## Step 6: Split-Horizon DNS (Advanced)

For more complex scenarios, you can implement split-horizon DNS:

### 6.1 Internal vs External Resolution

Create separate views for internal and external clients:

1. **Internal View** (on-premises clients):
   - `backend.backelant.eu` → `<ACA_STATIC_IP>`
   - `frontend.backelant.eu` → `<ACA_STATIC_IP>`

2. **External View** (internet clients):
   - `backend.backelant.eu` → Public IP or CNAME
   - `frontend.backelant.eu` → Public IP or CNAME

### 6.2 Configuration Example

```json
{
  "zones": [
    {
      "name": "backelant.eu",
      "type": "Primary",
      "records": [
        {
          "name": "backend",
          "type": "A",
          "value": "<ACA_STATIC_IP>",
          "view": "internal"
        },
        {
          "name": "backend", 
          "type": "A",
          "value": "<PUBLIC_IP>",
          "view": "external"
        }
      ]
    }
  ]
}
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: DNS queries timing out

**Symptoms**: `nslookup` commands hang or timeout

**Solutions**:
1. Check Technitium server is running: `systemctl status technitium-dns-server`
2. Verify firewall allows UDP/53: `sudo ufw allow 53/udp`
3. Test local resolution: `nslookup google.com 127.0.0.1`

#### Issue: Private link domains not resolving

**Symptoms**: Azure services resolve to public IPs instead of private

**Solutions**:
1. Verify VPN connectivity: `ping <DNS_RESOLVER_INBOUND_IP>`
2. Check conditional forwarder configuration
3. Test direct query: `nslookup domain.name <DNS_RESOLVER_INBOUND_IP>`
4. Verify Azure private DNS zone links

#### Issue: FleetPulse applications not accessible

**Symptoms**: DNS resolves but connection fails

**Solutions**:
1. Verify A record points to correct IP
2. Test connectivity: `telnet <ACA_STATIC_IP> 443`
3. Check Azure Container Apps status
4. Verify SSL certificate binding

### Monitoring and Maintenance

#### Health Checks

Create a monitoring script:

```bash
#!/bin/bash
# DNS health check script

DOMAINS=("backend.backelant.eu" "frontend.backelant.eu")
DNS_SERVER="<TECHNITIUM_SERVER_IP>"

for domain in "${DOMAINS[@]}"; do
    result=$(nslookup $domain $DNS_SERVER | grep "Address:" | tail -1 | awk '{print $2}')
    if [ "$result" = "<ACA_STATIC_IP>" ]; then
        echo "✅ $domain resolves correctly to $result"
    else
        echo "❌ $domain resolution failed. Got: $result"
    fi
done
```

#### Log Rotation

Configure log rotation to prevent disk space issues:

```bash
# Add to /etc/logrotate.d/technitium-dns
/var/log/technitium-dns-server/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 technitium technitium
}
```

## Security Considerations

### 1. Access Control
- Limit DNS queries to trusted networks only
- Use firewall rules to restrict access to port 53
- Consider DNS over HTTPS (DoH) for encrypted queries

### 2. Monitoring
- Enable query logging for security auditing
- Monitor for suspicious query patterns
- Set up alerts for service disruptions

### 3. Updates
- Keep Technitium DNS updated with latest security patches
- Review and update configurations regularly
- Backup configuration before making changes

## Configuration Backup

### Export Configuration

```bash
# Backup Technitium configuration
curl -X GET "http://<TECHNITIUM_SERVER_IP>:5380/api/settings/backup" \
  -H "Authorization: Bearer <API_TOKEN>" \
  --output technitium-backup-$(date +%Y%m%d).zip
```

### Import Configuration

```bash
# Restore from backup
curl -X POST "http://<TECHNITIUM_SERVER_IP>:5380/api/settings/restore" \
  -H "Authorization: Bearer <API_TOKEN>" \
  -F "backupFile=@technitium-backup.zip"
```

## Performance Optimization

### DNS Cache Optimization

```json
{
  "cacheSettings": {
    "maxTtl": 86400,
    "minTtl": 60,
    "negativeTtl": 300,
    "prefetchEligibility": 2,
    "prefetchTrigger": 9,
    "prefetchSampleIntervalPerSecond": 5
  }
}
```

### Resource Monitoring

Monitor system resources:

```bash
# Check memory usage
free -h

# Check disk usage
df -h /var/lib/technitium-dns-server

# Monitor DNS query rate
tail -f /var/log/technitium-dns-server/query.log | wc -l
```

## Integration with Network Monitoring

Consider integrating with monitoring solutions:

- **Prometheus**: Export DNS metrics
- **Grafana**: Create DNS dashboards
- **Nagios**: Monitor DNS service availability
- **PRTG**: Network monitoring with DNS sensors

This configuration provides a robust DNS foundation for the FleetPulse Azure deployment while maintaining security and performance.