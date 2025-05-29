# Terraform MCP Server - Azure Deployment

Deploy the Terraform MCP Server to Azure Container Apps with secure Key Vault integration.

## Files in this Project

- `terraform-mcp-keyvault.tf` - Azure infrastructure configuration
- `mcp-sse-server.py` - Python SSE wrapper for the MCP server  
- `Dockerfile` - Container build configuration
- `deploy.ps1` - PowerShell deployment script

## Prerequisites

1. **Terraform** - [Download](https://www.terraform.io/downloads)
2. **Azure CLI** - [Download](https://aka.ms/installazurecliwindows)
3. **VS Code** with GitHub Copilot

## Deployment

1. Start PowerShell or Command Prompt
2. Run:
```powershell
./deploy.ps1
```

The script will:
1. Check prerequisites
2. Clean up any soft-deleted Key Vaults
3. Deploy Azure infrastructure using Terraform
4. Build and push Docker image using Azure Container Registry
5. Create VS Code configuration

## Infrastructure Components

- **Azure Resource Group** - Contains all resources
- **Azure Key Vault** - Securely stores API key
- **Azure Container Registry** - Stores Docker images
- **Azure Container Apps Environment** - Hosting platform
- **Container App** - Runs the MCP server
- **Log Analytics Workspace** - Collects logs and metrics
- **Managed Identity** - For secure access to Key Vault

## Security Features

- API key stored in Azure Key Vault
- HTTPS enabled by default
- Key Vault RBAC authorization
- Managed Identity for secure access
- Bearer token authentication

## Using with VS Code

1. Open VS Code in this directory
2. The deployment creates `.vscode/mcp.json` with your configuration
3. Press `Ctrl+Alt+I` to open GitHub Copilot Chat
4. Select "Agent" mode
5. Start using Terraform tools!

## Cleanup

Remove all Azure resources:
```powershell
terraform destroy -auto-approve
```