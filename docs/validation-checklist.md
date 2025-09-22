# FleetPulse Azure Infrastructure Validation Checklist

This checklist provides a comprehensive validation process for the FleetPulse Azure Container Apps deployment to ensure all components are working correctly.

## Pre-Validation Requirements

- [ ] Azure infrastructure deployed successfully via Terraform
- [ ] VPN connection established between OPNsense and Azure
- [ ] DNS configuration completed on Technitium server
- [ ] SSL certificates uploaded to Key Vault
- [ ] Post-deploy configuration completed

## 1. Network Connectivity Validation

### 1.1 VPN Connectivity

From on-premises network:

```bash
# Test Azure VNET connectivity
ping 10.20.0.4
# Expected: Successful ping responses

# Test specific Azure services
ping 10.20.0.132  # DNS Private Resolver
# Expected: Successful ping responses

# Test Azure VPN Gateway connectivity
ping <AZURE_VPN_GATEWAY_PRIVATE_IP>
# Expected: Successful ping responses
```

**Checklist:**
- [ ] Can ping Azure VNET IP ranges from on-premises
- [ ] Can ping DNS Private Resolver inbound endpoint
- [ ] VPN tunnel shows as connected in OPNsense
- [ ] VPN tunnel shows as connected in Azure Portal

### 1.2 DNS Resolution

From on-premises client:

```bash
# Test FleetPulse application DNS resolution
nslookup backend.backelant.eu
# Expected: Returns <ACA_STATIC_IP>

nslookup frontend.backelant.eu  
# Expected: Returns <ACA_STATIC_IP>

# Test Azure private link DNS resolution
nslookup <KEYVAULT_NAME>.vault.azure.net
# Expected: Returns private IP (10.20.0.x)

nslookup <STORAGE_ACCOUNT>.file.core.windows.net
# Expected: Returns private IP (10.20.0.x)
```

**Checklist:**
- [ ] FleetPulse domains resolve to ACA internal IP
- [ ] Key Vault resolves to private endpoint IP
- [ ] Storage Account resolves to private endpoint IP
- [ ] Application Insights resolves to private endpoint IP
- [ ] Public domains still resolve correctly (e.g., google.com)

## 2. Azure Infrastructure Validation

### 2.1 Container Apps Environment

```bash
# Check ACA environment status
az containerapp env show \
  --name <ACA_ENV_NAME> \
  --resource-group <RESOURCE_GROUP_NAME> \
  --query '{name:name,provisioningState:properties.provisioningState,staticIp:properties.staticIp}'

# Expected output:
# {
#   "name": "fleetpulse-prod-aca-env",
#   "provisioningState": "Succeeded", 
#   "staticIp": "<ACA_STATIC_IP>"
# }
```

**Checklist:**
- [ ] ACA environment status is "Succeeded"
- [ ] Static IP matches expected value
- [ ] Internal load balancer is configured
- [ ] Log Analytics workspace is connected

### 2.2 Container Apps Status

```bash
# List all container apps
az containerapp list \
  --resource-group <RESOURCE_GROUP_NAME> \
  --query '[].{name:name,status:properties.provisioningState,fqdn:properties.configuration.ingress.fqdn}' \
  --output table

# Check individual app status
az containerapp show \
  --name fleetpulse-prod-backend \
  --resource-group <RESOURCE_GROUP_NAME> \
  --query '{name:name,status:properties.provisioningState,replicas:properties.template.scale}'
```

**Checklist:**
- [ ] Backend container app status is "Succeeded"
- [ ] Frontend container app status is "Succeeded"
- [ ] OpenTelemetry collector status is "Succeeded"
- [ ] All apps have internal FQDNs assigned
- [ ] Minimum replica count is met

### 2.3 Storage Configuration

```bash
# Check ACA environment storage
az containerapp env storage show \
  --name <ACA_ENV_NAME> \
  --resource-group <RESOURCE_GROUP_NAME> \
  --storage-name files

# Expected: Shows Azure Files configuration
```

**Checklist:**
- [ ] Azure Files storage is configured in ACA environment
- [ ] Storage account is accessible via private endpoint
- [ ] File share "fleetpulse" exists and is accessible
- [ ] Backend app has storage mount configured

## 3. Application Functionality Validation

### 3.1 Backend Application

From on-premises network:

```bash
# Test backend health endpoint
curl -k https://backend.backelant.eu:8000/health
# Expected: HTTP 200 response with health status

# Test with verbose output for troubleshooting
curl -v -k https://backend.backelant.eu:8000/health

# Test backend API endpoints (adjust based on your API)
curl -k https://backend.backelant.eu:8000/api/version
curl -k https://backend.backelant.eu:8000/api/status
```

**Checklist:**
- [ ] Health endpoint returns HTTP 200
- [ ] SSL certificate is working (if configured)
- [ ] API endpoints respond correctly
- [ ] Response times are acceptable (<2 seconds)
- [ ] Backend can access Azure Files storage

### 3.2 Frontend Application

```bash
# Test frontend application
curl -k https://frontend.backelant.eu
# Expected: HTTP 200 response with HTML content

# Test specific frontend resources
curl -k https://frontend.backelant.eu/static/css/main.css
curl -k https://frontend.backelant.eu/favicon.ico
```

**Checklist:**
- [ ] Frontend returns HTTP 200
- [ ] HTML content is served correctly
- [ ] Static resources load properly
- [ ] SSL certificate is working (if configured)
- [ ] Frontend can communicate with backend

### 3.3 OpenTelemetry Collector

```bash
# Test OTLP endpoint (internal)
# This would typically be tested from within the ACA environment
# or through application telemetry verification
```

**Checklist:**
- [ ] OpenTelemetry collector is receiving traces
- [ ] Telemetry is being exported to Application Insights
- [ ] No error logs in collector application
- [ ] OTLP endpoints are accessible internally

## 4. Security Validation

### 4.1 Network Security

```bash
# Test that applications are NOT accessible from internet
# (Run from external network/public internet)
curl -k https://backend.backelant.eu:8000/health --connect-timeout 10
# Expected: Connection timeout or DNS resolution failure

# Test network isolation
nmap -p 443,80,8000 backend.backelant.eu
# Expected: Ports should be filtered/closed from external networks
```

**Checklist:**
- [ ] Applications are NOT accessible from public internet
- [ ] Applications are only accessible from trusted networks via VPN
- [ ] IP restrictions are working correctly at application level
- [ ] Container Apps use internal load balancer only
- [ ] Azure Policy prevents external network access
- [ ] VPN is required for all access

> **Note**: Azure Firewall was removed for cost optimization. Network security relies on private networking, VPN-only access, and application-level IP restrictions.

### 4.2 Key Vault Security

```bash
# Test Key Vault access (requires authentication)
az keyvault secret list --vault-name <KEYVAULT_NAME>
# Expected: Requires authentication and proper RBAC

# Verify private endpoint
nslookup <KEYVAULT_NAME>.vault.azure.net
# Expected: Resolves to private IP
```

**Checklist:**
- [ ] Key Vault is only accessible via private endpoint
- [ ] Secrets are properly stored and encrypted
- [ ] RBAC permissions are correctly configured
- [ ] Managed identity can access required secrets
- [ ] Public access is disabled

### 4.3 Storage Security

```bash
# Test storage account access
az storage blob list --account-name <STORAGE_ACCOUNT> --container-name '$root'
# Expected: Access only via private endpoint

# Verify private endpoint resolution
nslookup <STORAGE_ACCOUNT>.file.core.windows.net
# Expected: Resolves to private IP
```

**Checklist:**
- [ ] Storage account is only accessible via private endpoint
- [ ] Public access is disabled
- [ ] Azure Files share is properly secured
- [ ] SMB encryption is enabled
- [ ] Soft delete is configured

## 5. Monitoring and Observability Validation

### 5.1 Application Insights

```bash
# Check Application Insights data ingestion
az monitor app-insights query \
  --app <APPLICATION_INSIGHTS_NAME> \
  --analytics-query "requests | where timestamp > ago(1h) | count"

# Check for traces
az monitor app-insights query \
  --app <APPLICATION_INSIGHTS_NAME> \
  --analytics-query "traces | where timestamp > ago(1h) | take 10"
```

**Checklist:**
- [ ] Application telemetry is flowing to Application Insights
- [ ] Traces from OpenTelemetry collector are visible
- [ ] Request metrics are being captured
- [ ] Error logs are being captured
- [ ] AMPLS private connectivity is working

### 5.2 Container App Logs

```bash
# Check container app logs
az containerapp logs show \
  --name fleetpulse-prod-backend \
  --resource-group <RESOURCE_GROUP_NAME> \
  --follow

# Check for errors or warnings
az containerapp logs show \
  --name fleetpulse-prod-backend \
  --resource-group <RESOURCE_GROUP_NAME> \
  --format text | grep -i error
```

**Checklist:**
- [ ] Application logs are being generated
- [ ] No critical errors in logs
- [ ] Log Analytics workspace is receiving logs
- [ ] Log retention is configured appropriately

## 6. Performance Validation

### 6.1 Application Performance

```bash
# Test response times
time curl -k https://backend.backelant.eu:8000/health

# Load testing (using Apache Bench)
ab -n 100 -c 10 https://backend.backelant.eu:8000/health

# Test scaling behavior
# Monitor replica count during load
az containerapp revision list \
  --name fleetpulse-prod-backend \
  --resource-group <RESOURCE_GROUP_NAME> \
  --query '[].{name:name,replicas:properties.replicas}'
```

**Checklist:**
- [ ] Response times are acceptable (<2 seconds)
- [ ] Application handles concurrent requests
- [ ] Auto-scaling works as expected
- [ ] No performance bottlenecks identified

### 6.2 Network Performance

```bash
# Test network latency
ping -c 10 backend.backelant.eu

# Test bandwidth (using iperf3 if available)
# This would need to be set up between on-premises and Azure
```

**Checklist:**
- [ ] Network latency is acceptable (<50ms for local traffic)
- [ ] VPN throughput meets requirements
- [ ] No packet loss observed
- [ ] DNS resolution is fast (<100ms)

## 7. Disaster Recovery Validation

### 7.1 Data Backup

```bash
# Verify Azure Files backup/snapshot capability
az storage share snapshot \
  --name fleetpulse \
  --account-name <STORAGE_ACCOUNT>

# List snapshots
az storage share snapshot list \
  --name fleetpulse \
  --account-name <STORAGE_ACCOUNT>
```

**Checklist:**
- [ ] Azure Files snapshots can be created
- [ ] Data backup strategy is in place
- [ ] Recovery procedures are documented
- [ ] Backup retention meets requirements

### 7.2 Infrastructure Recovery

```bash
# Test Terraform plan for infrastructure recovery
cd infra/terraform/envs/prod
terraform plan -var-file="terraform.tfvars"
# Expected: Plan should show no changes for existing infrastructure
```

**Checklist:**
- [ ] Terraform state is properly backed up
- [ ] Infrastructure can be recreated from code
- [ ] Configuration secrets are recoverable
- [ ] DNS configuration is documented

## 8. Compliance and Governance

### 8.1 Azure Policy Compliance

```bash
# Check policy compliance
az policy state list \
  --resource-group <RESOURCE_GROUP_NAME> \
  --query '[?complianceState==`NonCompliant`]'
# Expected: Empty array (no non-compliant resources)
```

**Checklist:**
- [ ] All resources are compliant with Azure policies
- [ ] Container Apps external access policy is enforced
- [ ] Security policies are applied correctly
- [ ] Tagging policies are complied with

### 8.2 Security Scanning

```bash
# Run Trivy security scan on container images
trivy image wesback/fleetpulse-backend:latest
trivy image wesback/fleetpulse-frontend:latest

# Check for high/critical vulnerabilities
trivy image --severity HIGH,CRITICAL wesback/fleetpulse-backend:latest
```

**Checklist:**
- [ ] Container images have no critical vulnerabilities
- [ ] Security scanning is integrated into CI/CD
- [ ] Regular security updates are planned
- [ ] Vulnerability management process is in place

## 9. Documentation and Training

**Checklist:**
- [ ] All infrastructure is documented
- [ ] Operational procedures are documented
- [ ] Team has been trained on new architecture
- [ ] Troubleshooting guides are available
- [ ] Emergency contacts and procedures are defined

## 10. Go-Live Checklist

**Final validation before switching production traffic:**

- [ ] All technical validations above are passing
- [ ] Performance testing completed successfully
- [ ] Security review completed and approved
- [ ] Monitoring and alerting configured
- [ ] Backup and recovery procedures tested
- [ ] Team training completed
- [ ] Documentation is up to date
- [ ] Rollback plan is documented and tested
- [ ] Communication plan for users is ready
- [ ] Post-deployment monitoring plan is in place

## Troubleshooting Common Issues

### Issue: DNS Resolution Failures

```bash
# Debug DNS resolution
dig backend.backelant.eu @<TECHNITIUM_SERVER_IP>
nslookup backend.backelant.eu <TECHNITIUM_SERVER_IP>

# Check DNS server logs
tail -f /var/log/technitium-dns-server/query.log
```

### Issue: VPN Connectivity Problems

```bash
# Check VPN status
az network vpn-connection show \
  --name <VPN_CONNECTION_NAME> \
  --resource-group <RESOURCE_GROUP_NAME> \
  --query connectionStatus

# Test Azure gateway connectivity
ping <AZURE_VPN_GATEWAY_IP>
```

### Issue: Application Not Responding

```bash
# Check container app status
az containerapp show \
  --name <APP_NAME> \
  --resource-group <RESOURCE_GROUP_NAME> \
  --query properties.provisioningState

# View application logs
az containerapp logs show \
  --name <APP_NAME> \
  --resource-group <RESOURCE_GROUP_NAME> \
  --tail 50
```

### Issue: SSL Certificate Problems

```bash
# Test SSL certificate
openssl s_client -connect backend.backelant.eu:443 -servername backend.backelant.eu

# Check certificate binding in ACA
az containerapp hostname list \
  --name <APP_NAME> \
  --resource-group <RESOURCE_GROUP_NAME>
```

## Validation Sign-Off

Once all validation steps are completed successfully:

- [ ] **Network Team**: VPN and DNS configuration validated
- [ ] **Security Team**: Security controls validated
- [ ] **Application Team**: Application functionality validated
- [ ] **Operations Team**: Monitoring and procedures validated
- [ ] **Project Manager**: All deliverables completed

**Validation completed by:** _____________________ **Date:** __________

**Approved for production use by:** _____________________ **Date:** __________