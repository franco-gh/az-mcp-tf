# Terraform MCP Server - Azure Deployment

Deploy the Terraform MCP Server to Azure Container Apps with secure Key Vault integration.

## Files in this Project

- `terraform-mcp-keyvault.tf` - Azure infrastructure configuration
- `mcp-sse-server.py` - Python SSE wrapper for the MCP server  
- `Dockerfile` - Container build configuration
- `deploy.ps1` - PowerShell deployment script
- `deploy.bat` - Windows batch file launcher
- `.vscode/mcp.json` - VS Code configuration (created after deployment)

## Prerequisites

1. **Terraform** - [Download](https://www.terraform.io/downloads)
2. **Azure CLI** - [Download](https://aka.ms/installazurecliwindows)
3. **VS Code** with GitHub Copilot

Note: Docker is NOT required on your local machine!

## Deployment

1. Open Command Prompt or PowerShell
2. Navigate to this directory
3. Run: `deploy.bat`

## What Gets Deployed

- Azure Resource Group
- Azure Key Vault (stores API key securely)
- Azure Container Registry
- Azure Container Apps Environment
- Container App running the MCP server
- Log Analytics Workspace

## After Deployment

Your API key will be:
- Generated automatically
- Stored securely in Azure Key Vault
- Displayed in the deployment output
- Configured in `.vscode/mcp.json`

## Using in VS Code

1. Open VS Code in this directory
2. Press `Ctrl+Alt+I` to open GitHub Copilot Chat
3. Select "Agent" mode from the dropdown
4. The Terraform MCP tools are now available!

## Costs

- Container Apps: ~$0.40/day when idle
- Key Vault: ~$0.03/month
- Container Registry: ~$5/month
- Log Analytics: ~$2.50/GB ingested

## Cleanup

To remove all resources:
```powershell
terraform destroy -auto-approve
```