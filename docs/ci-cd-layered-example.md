# CI/CD Pipeline for Layered Terraform Deployment

This document provides examples of how to implement CI/CD pipelines for the new layered Terraform structure.

## GitHub Actions Example

### Complete Workflow

```yaml
name: 'Terraform Layered Deployment'

on:
  push:
    branches: [ main ]
    paths: [ 'infra/terraform/**' ]
  pull_request:
    branches: [ main ]
    paths: [ 'infra/terraform/**' ]
  workflow_dispatch:
    inputs:
      layer:
        description: 'Layer to deploy (all, network, shared, platform, apps)'
        required: true
        default: 'all'
        type: choice
        options:
        - all
        - network
        - shared
        - platform
        - apps

env:
  TF_VERSION: '1.13.3'
  ARM_USE_AZUREAD: true
  ARM_SKIP_PROVIDER_REGISTRATION: true

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  plan-network:
    name: 'Plan Network Layer'
    runs-on: ubuntu-latest
    if: |
      (github.event_name == 'workflow_dispatch' && 
       (github.event.inputs.layer == 'all' || github.event.inputs.layer == 'network')) ||
      (github.event_name != 'workflow_dispatch')
    outputs:
      plan-changed: ${{ steps.plan.outputs.changed }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: infra/terraform/envs/prod-network
      run: terraform init -backend-config=backend.conf

    - name: Terraform Plan
      id: plan
      working-directory: infra/terraform/envs/prod-network
      run: |
        terraform plan -detailed-exitcode -no-color -out=tfplan
        echo "changed=$?" >> $GITHUB_OUTPUT
      env:
        TF_VAR_vpn_shared_key: ${{ secrets.TF_VAR_VPN_SHARED_KEY }}
        TF_VAR_on_premises_gateway_ip: ${{ secrets.TF_VAR_ON_PREMISES_GATEWAY_IP }}

    - name: Comment PR
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v7
      with:
        script: |
          const fs = require('fs');
          const plan = fs.readFileSync('infra/terraform/envs/prod-network/tfplan.txt', 'utf8');
          const output = `### Network Layer Plan
          \`\`\`terraform
          ${plan}
          \`\`\``;
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: output
          });

  plan-shared:
    name: 'Plan Shared Layer'
    runs-on: ubuntu-latest
    needs: plan-network
    if: |
      (github.event_name == 'workflow_dispatch' && 
       (github.event.inputs.layer == 'all' || github.event.inputs.layer == 'shared')) ||
      (github.event_name != 'workflow_dispatch')
    outputs:
      plan-changed: ${{ steps.plan.outputs.changed }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: infra/terraform/envs/prod-shared
      run: terraform init -backend-config=backend.conf

    - name: Terraform Plan
      id: plan
      working-directory: infra/terraform/envs/prod-shared
      run: |
        terraform plan -detailed-exitcode -no-color -out=tfplan
        echo "changed=$?" >> $GITHUB_OUTPUT

  plan-platform:
    name: 'Plan Platform Layer'
    runs-on: ubuntu-latest
    needs: [plan-network, plan-shared]
    if: |
      (github.event_name == 'workflow_dispatch' && 
       (github.event.inputs.layer == 'all' || github.event.inputs.layer == 'platform')) ||
      (github.event_name != 'workflow_dispatch')
    outputs:
      plan-changed: ${{ steps.plan.outputs.changed }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: infra/terraform/envs/prod-platform
      run: terraform init -backend-config=backend.conf

    - name: Terraform Plan
      id: plan
      working-directory: infra/terraform/envs/prod-platform
      run: |
        terraform plan -detailed-exitcode -no-color -out=tfplan
        echo "changed=$?" >> $GITHUB_OUTPUT

  plan-apps:
    name: 'Plan Apps Layer'
    runs-on: ubuntu-latest
    needs: [plan-network, plan-shared, plan-platform]
    if: |
      (github.event_name == 'workflow_dispatch' && 
       (github.event.inputs.layer == 'all' || github.event.inputs.layer == 'apps')) ||
      (github.event_name != 'workflow_dispatch')
    outputs:
      plan-changed: ${{ steps.plan.outputs.changed }}
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: infra/terraform/envs/prod-apps
      run: terraform init -backend-config=backend.conf

    - name: Terraform Plan
      id: plan
      working-directory: infra/terraform/envs/prod-apps
      run: |
        terraform plan -detailed-exitcode -no-color -out=tfplan
        echo "changed=$?" >> $GITHUB_OUTPUT
      env:
        TF_VAR_container_images: ${{ vars.TF_VAR_CONTAINER_IMAGES }}

  deploy-network:
    name: 'Deploy Network Layer'
    runs-on: ubuntu-latest
    needs: plan-network
    if: |
      github.ref == 'refs/heads/main' && 
      needs.plan-network.outputs.plan-changed == '2' &&
      ((github.event_name == 'workflow_dispatch' && 
        (github.event.inputs.layer == 'all' || github.event.inputs.layer == 'network')) ||
       (github.event_name == 'push'))
    environment: production
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: infra/terraform/envs/prod-network
      run: terraform init -backend-config=backend.conf

    - name: Terraform Apply
      working-directory: infra/terraform/envs/prod-network
      run: terraform apply -auto-approve
      env:
        TF_VAR_vpn_shared_key: ${{ secrets.TF_VAR_VPN_SHARED_KEY }}
        TF_VAR_on_premises_gateway_ip: ${{ secrets.TF_VAR_ON_PREMISES_GATEWAY_IP }}

  deploy-shared:
    name: 'Deploy Shared Layer'
    runs-on: ubuntu-latest
    needs: [plan-shared, deploy-network]
    if: |
      github.ref == 'refs/heads/main' && 
      needs.plan-shared.outputs.plan-changed == '2' &&
      ((github.event_name == 'workflow_dispatch' && 
        (github.event.inputs.layer == 'all' || github.event.inputs.layer == 'shared')) ||
       (github.event_name == 'push'))
    environment: production
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: infra/terraform/envs/prod-shared
      run: terraform init -backend-config=backend.conf

    - name: Terraform Apply
      working-directory: infra/terraform/envs/prod-shared
      run: terraform apply -auto-approve

  deploy-platform:
    name: 'Deploy Platform Layer'
    runs-on: ubuntu-latest
    needs: [plan-platform, deploy-network, deploy-shared]
    if: |
      github.ref == 'refs/heads/main' && 
      needs.plan-platform.outputs.plan-changed == '2' &&
      ((github.event_name == 'workflow_dispatch' && 
        (github.event.inputs.layer == 'all' || github.event.inputs.layer == 'platform')) ||
       (github.event_name == 'push'))
    environment: production
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: infra/terraform/envs/prod-platform
      run: terraform init -backend-config=backend.conf

    - name: Terraform Apply
      working-directory: infra/terraform/envs/prod-platform
      run: terraform apply -auto-approve

  deploy-apps:
    name: 'Deploy Apps Layer'
    runs-on: ubuntu-latest
    needs: [plan-apps, deploy-network, deploy-shared, deploy-platform]
    if: |
      github.ref == 'refs/heads/main' && 
      needs.plan-apps.outputs.plan-changed == '2' &&
      ((github.event_name == 'workflow_dispatch' && 
        (github.event.inputs.layer == 'all' || github.event.inputs.layer == 'apps')) ||
       (github.event_name == 'push'))
    environment: production
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}

    - name: Azure Login
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Terraform Init
      working-directory: infra/terraform/envs/prod-apps
      run: terraform init -backend-config=backend.conf

    - name: Terraform Apply
      working-directory: infra/terraform/envs/prod-apps
      run: terraform apply -auto-approve
      env:
        TF_VAR_container_images: ${{ vars.TF_VAR_CONTAINER_IMAGES }}
```

## Azure DevOps Pipeline Example

```yaml
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - infra/terraform/*

variables:
  terraformVersion: '1.13.3'
  backendRG: 'rg-terraform-state-prod'
  backendSA: 'stterraformstateprod'
  backendContainer: 'tfstate'

stages:
- stage: Plan
  displayName: 'Plan All Layers'
  jobs:
  - job: PlanNetwork
    displayName: 'Plan Network Layer'
    steps:
    - task: TerraformInstaller@0
      inputs:
        terraformVersion: $(terraformVersion)
    
    - task: AzureCLI@2
      displayName: 'Terraform Init & Plan Network'
      inputs:
        azureSubscription: 'prod-service-connection'
        scriptType: bash
        scriptLocation: inlineScript
        workingDirectory: infra/terraform/envs/prod-network
        inlineScript: |
          terraform init \
            -backend-config="resource_group_name=$(backendRG)" \
            -backend-config="storage_account_name=$(backendSA)" \
            -backend-config="container_name=$(backendContainer)" \
            -backend-config="key=prod-network.tfstate"
          terraform plan -out=tfplan

  - job: PlanShared
    displayName: 'Plan Shared Layer'
    dependsOn: PlanNetwork
    steps:
    - task: TerraformInstaller@0
      inputs:
        terraformVersion: $(terraformVersion)
    
    - task: AzureCLI@2
      displayName: 'Terraform Init & Plan Shared'
      inputs:
        azureSubscription: 'prod-service-connection'
        scriptType: bash
        scriptLocation: inlineScript
        workingDirectory: infra/terraform/envs/prod-shared
        inlineScript: |
          terraform init \
            -backend-config="resource_group_name=$(backendRG)" \
            -backend-config="storage_account_name=$(backendSA)" \
            -backend-config="container_name=$(backendContainer)" \
            -backend-config="key=prod-shared.tfstate"
          terraform plan -out=tfplan

- stage: Deploy
  displayName: 'Deploy All Layers'
  dependsOn: Plan
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployNetwork
    displayName: 'Deploy Network Layer'
    environment: 'production'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: TerraformInstaller@0
            inputs:
              terraformVersion: $(terraformVersion)
          
          - task: AzureCLI@2
            displayName: 'Terraform Apply Network'
            inputs:
              azureSubscription: 'prod-service-connection'
              scriptType: bash
              scriptLocation: inlineScript
              workingDirectory: infra/terraform/envs/prod-network
              inlineScript: |
                terraform init \
                  -backend-config="resource_group_name=$(backendRG)" \
                  -backend-config="storage_account_name=$(backendSA)" \
                  -backend-config="container_name=$(backendContainer)" \
                  -backend-config="key=prod-network.tfstate"
                terraform apply -auto-approve

  - deployment: DeployShared
    displayName: 'Deploy Shared Layer'
    dependsOn: DeployNetwork
    environment: 'production'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: TerraformInstaller@0
            inputs:
              terraformVersion: $(terraformVersion)
          
          - task: AzureCLI@2
            displayName: 'Terraform Apply Shared'
            inputs:
              azureSubscription: 'prod-service-connection'
              scriptType: bash
              scriptLocation: inlineScript
              workingDirectory: infra/terraform/envs/prod-shared
              inlineScript: |
                terraform init \
                  -backend-config="resource_group_name=$(backendRG)" \
                  -backend-config="storage_account_name=$(backendSA)" \
                  -backend-config="container_name=$(backendContainer)" \
                  -backend-config="key=prod-shared.tfstate" 
                terraform apply -auto-approve
```

## Key Features

### 1. Layer Dependencies
- Each layer waits for its dependencies to complete
- Network → Shared → Platform → Apps order is enforced
- Failures in upstream layers stop downstream deployments

### 2. Selective Deployment
- Manual workflow dispatch allows deploying specific layers
- Automatic detection of changes in each layer
- Skip layers with no changes to save time

### 3. Security
- Uses OIDC for passwordless authentication
- Secrets managed through GitHub Secrets/Azure Key Vault
- Environment protection rules for production

### 4. State Management
- Each layer uses separate state files
- Remote state configuration prevents conflicts
- Proper backend initialization for each layer

## Required Secrets/Variables

### GitHub Secrets
```
AZURE_CLIENT_ID         # Service principal client ID
AZURE_TENANT_ID         # Azure tenant ID  
AZURE_SUBSCRIPTION_ID   # Azure subscription ID
TF_VAR_VPN_SHARED_KEY   # VPN pre-shared key
TF_VAR_ON_PREMISES_GATEWAY_IP  # OPNsense public IP
```

### GitHub Variables
```
TF_VAR_CONTAINER_IMAGES # JSON object with container image versions
```

### Service Principal Permissions
The service principal needs these permissions:
- **Contributor** on the subscription (or resource groups)
- **Storage Blob Data Contributor** on the Terraform state storage account
- **Key Vault Administrator** (if managing Key Vault secrets)

## Best Practices

1. **Use Environment Protection**: Require manual approval for production deployments
2. **Plan First**: Always run plan jobs before apply jobs
3. **Artifact Storage**: Store Terraform plans as artifacts for audit trails
4. **Notification**: Add Slack/Teams notifications for deployment status
5. **Rollback**: Implement rollback procedures for failed deployments
6. **Monitoring**: Monitor pipeline execution and set up alerts for failures

## Example Deployment Scenarios

### Scenario 1: Network Change Only
- Network layer plan shows changes
- Other layers show no changes
- Only network layer is deployed
- Downstream layers remain unchanged

### Scenario 2: Application Update
- Only apps layer shows changes
- Network, shared, and platform layers skipped
- Fast deployment focusing on application changes

### Scenario 3: New Environment Setup
- All layers show changes (new environment)
- Deploy in order: network → shared → platform → apps
- Full environment provisioned in single pipeline run

### Scenario 4: Emergency Rollback
- Use manual workflow dispatch
- Deploy apps layer with previous image versions
- Fast rollback without affecting infrastructure layers