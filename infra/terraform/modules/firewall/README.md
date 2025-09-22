# Azure Firewall Module

> **Status**: Currently unused for cost optimization

This module creates Azure Firewall with User Defined Routes (UDR) for egress traffic control from Container Apps Environment.

## When to Use This Module

Consider enabling this module when:
- You need centralized egress traffic control
- Compliance requires advanced threat protection
- You have strict security requirements for outbound traffic
- The application scope expands beyond simple web app + API
- Cost of €100/month is justified by security benefits

## Current Architecture Without Firewall

The current deployment uses:
- Private Container Apps (no public endpoints)
- Internal load balancer only
- VPN-only access via Site-to-Site connection
- Application-level IP restrictions
- Private endpoints for all Azure services

## To Re-enable

1. Uncomment the firewall module in `envs/prod/main.tf`
2. Uncomment firewall subnet in `modules/vnet/main.tf` and `vnet/outputs.tf`
3. Add back firewall subnet CIDR in variables
4. Update documentation to reflect firewall protection

## Cost Impact

Enabling this module adds approximately €100/month to infrastructure costs.