# Migration Guide: Monolithic to Layered Terraform

This guide provides step-by-step instructions for migrating from the existing monolithic Terraform configuration to the new layered approach.

## ⚠️ Pre-Migration Checklist

- [ ] **Backup existing state**: Copy current `terraform.tfstate` files
- [ ] **Document current resources**: List all deployed resources
- [ ] **Set up remote state**: Configure Azure Storage for new backend
- [ ] **Test access**: Ensure Azure credentials work for both old and new structures
- [ ] **Schedule maintenance window**: Plan for potential downtime during migration

## Migration Strategy Overview

The migration uses Terraform's `import` functionality to move existing resources from the monolithic state to the appropriate layered states **without recreating resources**.

### High-Level Process

1. **Create layered configurations** (already done in this refactor)
2. **Set up remote state backends** for each layer
3. **Import existing resources** into appropriate layers
4. **Verify zero-drift plans** for each layer
5. **Remove resources** from monolithic configuration
6. **Cleanup** old configuration once verified

## Step-by-Step Migration

### Step 1: Backup Current State

```bash
cd infra/terraform/envs/prod

# Create backup of current state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)

# Export current resource list for reference
terraform state list > resources-before-migration.txt
```

### Step 2: Set Up Remote State Backend

If not already done, create the storage account for Terraform state:

```bash
# Create resource group for Terraform state
az group create --name rg-terraform-state-prod --location "West Europe"

# Create storage account (use unique name)
az storage account create \
  --name stwbtfstateprod \
  --resource-group rg-terraform-state-prod \
  --location "West Europe" \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name stwbtfstateprod
```

### Step 3: Configure Each Layer

Create configuration files for each layer:

```bash
cd infra/terraform/envs

# Configure each layer
for layer in prod-network prod-shared prod-platform prod-apps; do
  cd $layer
  cp terraform.tfvars.example terraform.tfvars
  cp backend.conf.example backend.conf
  # Edit files with your actual values
  cd ..
done
```

### Step 4: Import Network Layer Resources

```bash
cd prod-network

# Initialize with remote backend
terraform init -backend-config=backend.conf

# Import network resources (adjust resource IDs for your subscription)
SUBSCRIPTION_ID="your-subscription-id"
RG_NAME="rg-fleetpulse-prod"

# Resource Group
terraform import azurerm_resource_group.main \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"

# VNet and Subnets (via module)
terraform import 'module.vnet.azurerm_virtual_network.main' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/vnet-fleetpulse-prod"

terraform import 'module.vnet.azurerm_subnet.aca_infra' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/vnet-fleetpulse-prod/subnets/snet-aca-infra"

terraform import 'module.vnet.azurerm_subnet.gateway' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/vnet-fleetpulse-prod/subnets/GatewaySubnet"

terraform import 'module.vnet.azurerm_subnet.privatelink' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/vnet-fleetpulse-prod/subnets/snet-privatelink"

terraform import 'module.vnet.azurerm_subnet.dns_resolver_inbound' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/vnet-fleetpulse-prod/subnets/snet-dnsresolver-inbound"

# VPN Gateway resources
terraform import 'module.gateway.azurerm_public_ip.vpn_gateway' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/publicIPAddresses/pip-vpngw-fleetpulse-prod"

terraform import 'module.gateway.azurerm_virtual_network_gateway.vpn' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworkGateways/vpngw-fleetpulse-prod"

terraform import 'module.gateway.azurerm_local_network_gateway.opnsense' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/localNetworkGateways/lng-opnsense-fleetpulse-prod"

terraform import 'module.gateway.azurerm_virtual_network_gateway_connection.s2s' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/connections/cn-s2s-fleetpulse-prod"

# DNS Resolver resources  
terraform import 'module.dns_resolver.azurerm_private_dns_resolver.main' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/dnsResolvers/dnsresolver-fleetpulse-prod"

terraform import 'module.dns_resolver.azurerm_private_dns_resolver_inbound_endpoint.main' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/dnsResolvers/dnsresolver-fleetpulse-prod/inboundEndpoints/inbound-endpoint"

# Verify no changes needed
terraform plan
```

**Important**: The exact resource names and IDs will depend on your actual deployment. Use `az resource list` to find the correct resource IDs.

### Step 5: Import Shared Layer Resources

```bash
cd ../prod-shared

terraform init -backend-config=backend.conf

# Key Vault resources
terraform import 'module.keyvault.azurerm_key_vault.main' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/kv-fleetpulse-prod"

terraform import 'module.keyvault.azurerm_private_endpoint.keyvault' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/privateEndpoints/pe-kv-fleetpulse-prod"

# Storage resources
terraform import 'module.storage.azurerm_storage_account.main' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/stfleetpulseprod"

terraform import 'module.storage.azurerm_storage_share.fleetpulse' \
  "https://stfleetpulseprod.file.core.windows.net/fleetpulse"

terraform import 'module.storage.azurerm_private_endpoint.storage' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/privateEndpoints/pe-st-fleetpulse-prod"

# Monitor resources  
terraform import 'module.monitor.azurerm_log_analytics_workspace.main' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.OperationalInsights/workspaces/log-fleetpulse-prod"

terraform import 'module.monitor.azurerm_application_insights.main' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Insights/components/appi-fleetpulse-prod"

# Verify no changes needed
terraform plan
```

### Step 6: Import Platform Layer Resources

```bash
cd ../prod-platform

terraform init -backend-config=backend.conf

# Policy resources
terraform import 'module.policy.azurerm_policy_assignment.container_apps_allowed_images' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Authorization/policyAssignments/allowed-container-images"

# Container Apps Environment
terraform import 'module.aca_env.azurerm_container_app_environment.main' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.App/managedEnvironments/aca-env-fleetpulse-prod"

terraform import 'module.aca_env.azurerm_private_dns_zone.aca_env' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/privateDnsZones/some.azurecontainerapps.io"

# Verify no changes needed
terraform plan
```

### Step 7: Import Apps Layer Resources

```bash
cd ../prod-apps

terraform init -backend-config=backend.conf

# Container Apps
terraform import 'module.apps.azurerm_container_app.backend' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.App/containerApps/ca-backend-fleetpulse-prod"

terraform import 'module.apps.azurerm_container_app.frontend' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.App/containerApps/ca-frontend-fleetpulse-prod"

terraform import 'module.apps.azurerm_container_app.otel_collector' \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.App/containerApps/ca-otel-fleetpulse-prod"

# Verify no changes needed  
terraform plan
```

### Step 8: Verify All Layers

Run plans on all layers to ensure no changes are detected:

```bash
cd ../prod-network && terraform plan
cd ../prod-shared && terraform plan  
cd ../prod-platform && terraform plan
cd ../prod-apps && terraform plan
```

All plans should show **"No changes. Your infrastructure matches the configuration."**

### Step 9: Remove Resources from Monolithic Configuration

Only proceed if all layer plans show zero changes:

```bash
cd ../prod

# Create backup before making changes
cp main.tf main.tf.backup

# Edit main.tf to remove all resource blocks that have been imported
# Keep only the locals and provider configuration

# Verify plan shows only deletions (no additions or changes)
terraform plan

# DO NOT APPLY YET - this would delete the resources from Azure
# The resources still exist, just not tracked by this state
```

### Step 10: Test New Layered Structure

Deploy a small test change through the layers to verify everything works:

```bash
# Example: Add a tag to verify the system works
cd ../prod-network
# Add a test tag to variables
terraform apply

# Verify the change was applied successfully
# Remove the test tag
terraform apply
```

### Step 11: Update CI/CD Pipelines

Update any GitHub Actions or other CI/CD pipelines to use the new layered structure:

```yaml
# Example workflow update
jobs:
  deploy-network:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy Network Layer
        run: |
          cd infra/terraform/envs/prod-network
          terraform init -backend-config=backend.conf
          terraform apply -auto-approve
          
  deploy-shared:
    needs: deploy-network
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy Shared Layer
        run: |
          cd infra/terraform/envs/prod-shared  
          terraform init -backend-config=backend.conf
          terraform apply -auto-approve
```

### Step 12: Cleanup

After successful migration and testing:

```bash
# Move old configuration to archive folder
cd infra/terraform/envs
mkdir archive
mv prod archive/prod-monolithic-$(date +%Y%m%d)

# Update documentation and notify team
```

## Troubleshooting

### Import Errors

**"Resource already exists"**: Resource has already been imported, or name conflict exists.
- Check `terraform state list` to see what's already imported
- Verify resource names match exactly

**"Resource not found"**: Incorrect resource ID or resource doesn't exist.
- Use `az resource list --resource-group $RG_NAME` to find correct IDs
- Check resource exists in Azure Portal

**"Import failed"**: Terraform configuration doesn't match actual resource.
- Compare Terraform config with actual resource properties in Azure
- Adjust configuration to match actual resource state

### State Issues

**"Backend initialization failed"**: Storage account or container doesn't exist.
- Verify storage account exists and is accessible
- Check authentication and permissions

**"State lock errors"**: Concurrent Terraform operations.
- Wait for other operations to complete
- If hung, carefully break state lock: `terraform force-unlock LOCK_ID`

### Plan Shows Changes After Import

**Configuration drift**: Terraform config doesn't exactly match imported resource.
- Update Terraform configuration to match actual resource state
- Consider if the difference is intentional and needs to be applied

## Rollback Plan

If migration fails and you need to rollback:

1. **Stop using new layered structure** immediately
2. **Restore monolithic state** from backup:
   ```bash
   cd infra/terraform/envs/prod
   cp terraform.tfstate.backup.TIMESTAMP terraform.tfstate
   ```
3. **Verify old structure works**:
   ```bash
   terraform plan  # Should show no changes
   ```
4. **Clean up new layer states** if needed:
   ```bash
   # Delete state files from Azure Storage if necessary
   ```

## Post-Migration Validation

- [ ] All resources exist and are functional
- [ ] All layers plan with zero changes
- [ ] Applications are accessible and working
- [ ] CI/CD pipelines work with new structure
- [ ] Team is trained on new deployment process
- [ ] Documentation is updated
- [ ] Old configurations are archived

## Benefits After Migration

✅ **Improved Security**: Separate state files limit blast radius
✅ **Better Governance**: Independent layer permissions and approvals  
✅ **Faster Deployments**: Only affected layers need to be planned/applied
✅ **Reduced Risk**: Changes to apps don't risk network infrastructure
✅ **Easier Maintenance**: Clear separation of concerns
✅ **Better Scalability**: Can scale teams and environments independently