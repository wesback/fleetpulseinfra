# FleetPulse Azure Container Apps Infrastructure

This repository contains production-grade infrastructure code to migrate FleetPulse from Docker Compose to Azure Container Apps (ACA) with private networking, Site-to-Site VPN connectivity, and comprehensive security controls.

## 🏗️ Architecture Overview

```
                    Internet
                       │
                  ┌────┴────┐
                  │ OPNsense │ (On-premises)
                  │ Router   │
                  └────┬────┘
                       │ Site-to-Site VPN
                       │
              ┌────────┴────────┐
              │ Azure VPN Gateway│
              └────────┬────────┘
                       │
          ┌────────────┴────────────┐
          │      Azure VNET         │
          │   (10.20.0.0/24)       │
          ├─────────────────────────┤
          │ Azure Firewall + UDR    │ ← Egress Control
          ├─────────────────────────┤
          │ Container Apps Env      │
          │ (Internal Load Balancer)│
          │                         │
          │ ┌─────┐ ┌─────┐ ┌─────┐ │
          │ │Back │ │Front│ │OTEL │ │
          │ │end  │ │end  │ │Coll │ │
          │ └─────┘ └─────┘ └─────┘ │
          └─────────────────────────┘
                       │
          ┌─────────────────────────┐
          │ Private Endpoints       │
          │ • Key Vault            │
          │ • Azure Files          │
          │ • Application Insights │
          └─────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

1. **Azure CLI** installed and configured
2. **Terraform** >= 1.6.0
3. **Docker** (for image building)
4. **Azure subscription** with Contributor access
5. **OPNsense router** with public IP
6. **Technitium DNS** server on-premises
7. **SSL certificate** for `*.backelant.eu`

### 1. Setup Azure Authentication (OIDC)

Create a service principal with OIDC federation for GitHub Actions:

```bash
# Create service principal
az ad sp create-for-rbac --name "fleetpulse-github-actions" \
  --role "Contributor" \
  --scopes "/subscriptions/YOUR_SUBSCRIPTION_ID"

# Configure OIDC federation
az ad app federated-credential create \
  --id YOUR_APP_ID \
  --parameters @oidc-credential.json
```

Set these GitHub repository secrets:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

### 2. Configure Terraform Variables

```bash
cd infra/terraform/envs/prod
cp terraform.tfvars.example terraform.tfvars
```

Update `terraform.tfvars` with your actual values:

| Variable | Description | Example |
|----------|-------------|---------|
| `on_premises_gateway_ip` | OPNsense public IP | `203.0.113.1` |
| `on_premises_networks` | On-prem network CIDRs | `["192.168.0.0/24"]` |
| `home_cidrs` | Trusted network CIDRs | `["192.168.0.0/24"]` |
| `vpn_shared_key` | Strong PSK for VPN | `your-strong-psk-here` |
| `custom_domains` | Your domain names | See example file |

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply (or use GitHub Actions)
terraform apply -var-file="terraform.tfvars"
```

### 4. Configure DNS and VPN

After deployment, configure:

1. **OPNsense VPN**: See [docs/opnsense-ipsec.md](docs/opnsense-ipsec.md)
2. **Technitium DNS**: See [docs/technitium-dns.md](docs/technitium-dns.md)
3. **SSL Certificates**: Upload to Key Vault and run post-deploy script

### 5. Validation

```bash
# Test VPN connectivity
ping 10.20.0.4  # ACA environment IP

# Test DNS resolution
nslookup backend.backelant.eu

# Test HTTPS endpoints
curl -k https://backend.backelant.eu:8000/health
curl -k https://frontend.backelant.eu
```

## 📁 Repository Structure

```
├── infra/terraform/
│   ├── envs/prod/              # Production environment
│   │   ├── main.tf             # Root module
│   │   ├── variables.tf        # Variable definitions
│   │   ├── outputs.tf          # Outputs
│   │   └── terraform.tfvars.example
│   └── modules/                # Reusable modules
│       ├── vnet/               # Virtual network
│       ├── gateway/            # VPN gateway
│       ├── firewall/           # Azure Firewall + UDR
│       ├── dns_resolver/       # DNS Private Resolver
│       ├── storage/            # Azure Files
│       ├── keyvault/           # Key Vault
│       ├── monitor/            # App Insights + AMPLS
│       ├── policy/             # Azure Policy
│       ├── aca_env/            # Container Apps Environment
│       └── apps/               # Container Apps
├── .github/workflows/          # CI/CD pipelines
├── docs/                       # Documentation
├── README.md                   # This file
├── SECURITY.md                 # Security policy
└── CODEOWNERS                  # Code ownership
```

## 🔐 Security Model

### Network Security
- **Private Container Apps** with internal load balancer only
- **Azure Firewall** controls all egress traffic
- **IP restrictions** limit access to trusted networks
- **Site-to-Site VPN** provides secure connectivity

### Identity & Access
- **Managed Identity** for all Azure service authentication
- **RBAC** controls access to Key Vault and resources
- **OIDC federation** eliminates stored secrets in CI/CD

### Data Protection
- **Private Endpoints** for all Azure services
- **Key Vault** stores all secrets and certificates
- **Azure Files** with private connectivity
- **TLS 1.2+** enforced everywhere

### Monitoring & Compliance
- **Azure Policy** enforces security requirements
- **Application Insights** with private telemetry
- **Azure Monitor Private Link Scope** (AMPLS)
- **Security scanning** in CI/CD pipeline

## 🔧 Operational Procedures

### Certificate Management

1. **Upload certificate to Key Vault**:
   ```bash
   az keyvault secret set --vault-name YOUR_KV_NAME \
     --name ssl-cert-pfx --file certificate.pfx
   
   az keyvault secret set --vault-name YOUR_KV_NAME \
     --name ssl-cert-password --value "cert-password"
   ```

2. **Run post-deploy configuration**:
   ```bash
   # Triggers automatically after Terraform deployment
   # Or manually via GitHub Actions
   ```

### Scaling Applications

```bash
# Scale backend
az containerapp update --name fleetpulse-prod-backend \
  --resource-group rg-fleetpulse-prod \
  --min-replicas 2 --max-replicas 10

# Scale frontend
az containerapp update --name fleetpulse-prod-frontend \
  --resource-group rg-fleetpulse-prod \
  --min-replicas 2 --max-replicas 5
```

### Data Migration

Migrate data from on-premises to Azure Files:

```bash
# Mount Azure Files share locally (from on-premises)
sudo mkdir -p /mnt/azure-files
sudo mount -t cifs //STORAGE_ACCOUNT.file.core.windows.net/fleetpulse \
  /mnt/azure-files -o username=STORAGE_ACCOUNT,password=STORAGE_KEY

# Copy data
rsync -av /mnt/data/dockervolumes/fleetpulse/ /mnt/azure-files/
```

### Disaster Recovery

1. **Backup**: Azure Files has built-in redundancy and soft delete
2. **Infrastructure**: Terraform state enables infrastructure recreation
3. **Configuration**: All configuration is in code (GitOps)

## 💰 Cost Optimization

Estimated monthly costs (West Europe):

| Service | Configuration | Est. Cost |
|---------|---------------|-----------|
| Container Apps | 3 apps, avg load | €50-100 |
| VPN Gateway | VpnGw1 | €25 |
| Azure Firewall | Standard | €100 |
| Storage | 100GB Files | €5 |
| Key Vault | Standard | €5 |
| App Insights | 1GB/month | €10 |
| **Total** | | **€195-245** |

Cost optimization tips:
- Use Consumption workload profile for variable loads
- Scale down non-production hours
- Monitor with cost alerts
- Review firewall rules regularly

## 🛠️ Development Workflow

1. **Feature branches**: Create feature branches for changes
2. **Pull requests**: All changes via PR with review
3. **CI/CD**: Automated testing and deployment
4. **Infrastructure changes**: Terraform plan on PR, apply on merge
5. **Security scanning**: Automated vulnerability scanning

## 📚 Additional Documentation

- [Technical Deep Dive](docs/blog.md)
- [OPNsense Configuration](docs/opnsense-ipsec.md)
- [Technitium DNS Setup](docs/technitium-dns.md)
- [Validation Checklist](docs/validation-checklist.md)

## 🆘 Troubleshooting

### Common Issues

**VPN not connecting:**
- Verify shared key matches on both sides
- Check firewall rules on OPNsense
- Validate IP addresses and subnets

**DNS not resolving:**
- Confirm conditional forwarders are configured
- Test DNS resolver endpoint connectivity
- Check private DNS zone linkage

**Container Apps not starting:**
- Review Container App logs: `az containerapp logs show`
- Verify managed identity permissions
- Check Key Vault access and secrets

**Storage mount fails:**
- Verify storage account key in ACA environment
- Check private endpoint connectivity
- Validate Azure Files share permissions

### Support

For issues:
1. Check [validation checklist](docs/validation-checklist.md)
2. Review Azure Activity Log
3. Open GitHub issue with logs and configuration

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Contributing

See [CODEOWNERS](CODEOWNERS) for code ownership and review requirements.

Security issues should be reported according to [SECURITY.md](SECURITY.md).