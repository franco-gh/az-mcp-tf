# Terraform MCP Server - Azure Deployment

This project provides a secure and automated way to deploy the `terraform-mcp-server` to Azure Container Apps. It uses a Python-based Server-Sent Events (SSE) wrapper to ensure compatibility with clients like the GitHub Copilot Chat extension in VS Code, which require SSE for communication.

Deployment is automated via GitHub Actions with Terraform Cloud integration, or can be done manually using Terraform and Azure CLI.

## Architecture

The following diagram illustrates the architecture of the deployed solution:

```
+---------------------+      +-----------------------------+      +---------------------------+
|      User         |      |     Azure Container App     |      | terraform-mcp-server      |
| (VS Code with     +----->| (Python SSE Wrapper)        +----->| (Running as a subprocess) |
| GitHub Copilot)   |      +-----------------------------+      +---------------------------+
+---------------------+      |                             |
                             |  +------------------------+ |
                             |  |   Managed Identity     | |
                             |  +------------------------+ |
                             |              |              |
                             |  +------------------------+ |
                             |  |   Azure Key Vault      | |
                             |  | (Stores API Key)       | |
                             |  +------------------------+ |
                             +-----------------------------+
```

## About the Project

The `terraform-mcp-server` is a component that provides an interface for interacting with Terraform. However, some clients, like the GitHub Copilot Chat extension, require a Server-Sent Events (SSE) endpoint for real-time communication. This project bridges that gap by providing a Python-based SSE wrapper that sits in front of the `terraform-mcp-server`.

The key features of this project are:

- **Automated Deployment:** CI/CD via GitHub Actions with Terraform Cloud for infrastructure management.
- **Secure by Design:** Azure Key Vault for API keys, Managed Identities for secure access, RBAC authorization.
- **Scalable:** Azure Container Apps with automatic scaling (1-3 replicas).
- **Easy to Use:** Once deployed, configure VS Code with the generated MCP configuration.

## Files in this Project

- **Terraform Infrastructure:**
  - `main.tf` - Resource Group, API key generation, Managed Identity
  - `keyvault.tf` - Key Vault with RBAC authorization
  - `container-registry.tf` - Azure Container Registry
  - `container-app.tf` - Container App and Log Analytics
  - `providers.tf` - Provider versions and Terraform Cloud config
  - `variables.tf` - Input variables
  - `outputs.tf` - URLs, credentials, MCP configuration
- `mcp-sse-server.py` - Python SSE wrapper for the MCP server
- `Dockerfile` - Container build configuration
- `.github/workflows/deploy.yml` - CI/CD pipeline

## Prerequisites

1. **Terraform** - [Download](https://www.terraform.io/downloads)
2. **Azure CLI** - [Download](https://aka.ms/installazurecliwindows)
3. **VS Code** with GitHub Copilot

## Deployment

### Automated (GitHub Actions + Terraform Cloud)

Push to `main` branch triggers the CI/CD pipeline which:
1. Runs `terraform apply` via Terraform Cloud
2. Builds Docker image in Azure Container Registry
3. Updates the Container App with the new image

**Required Setup:**
- GitHub Secrets: `TF_API_TOKEN`, `AZURE_CREDENTIALS`
- GitHub Variables: `TF_CLOUD_ORGANIZATION`, `TF_WORKSPACE`
- Terraform Cloud workspace with Azure credentials (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`)

### Manual Deployment

```bash
# 1. Deploy infrastructure
terraform init
terraform apply -auto-approve

# 2. Build and push Docker image
ACR_NAME=$(terraform output -raw acr_name)
az acr build --registry $ACR_NAME --image terraform-mcp-server:latest --file Dockerfile .

# 3. Update Container App
CONTAINER_APP=$(terraform output -raw container_app_name)
RG=$(terraform output -raw resource_group_name)
ACR_SERVER=$(terraform output -raw acr_login_server)
az containerapp update --name $CONTAINER_APP --resource-group $RG --image "$ACR_SERVER/terraform-mcp-server:latest"

# 4. Get MCP configuration for VS Code
terraform output -json mcp_config_claude_code_hosted
```

## Infrastructure Components

- **Azure Resource Group** - Contains all resources
- **Azure Key Vault** - Securely stores API key
- **Azure Container Registry** - Stores Docker images
- **Azure Container Apps Environment** - Hosting platform
- **Container App** - Runs the MCP server
- **Log Analytics Workspace** - Collects logs and metrics
- **Managed Identity** - For secure access to Key Vault

## Security Features

This solution is designed with security in mind, incorporating several best practices to protect your infrastructure and data.

- **API Key Authentication:** The SSE wrapper requires an API key for authentication, which is passed as a Bearer token in the `Authorization` header. This ensures that only authorized clients can access the `terraform-mcp-server`.

- **Azure Key Vault:** The API key is securely stored in Azure Key Vault, a cloud service for securely storing and accessing secrets. This avoids hardcoding secrets in the application code or configuration files.

- **Managed Identity:** The Azure Container App uses a Managed Identity to authenticate with Azure Key Vault. This eliminates the need for storing credentials in the application, as the authentication is handled by Azure Active Directory.

- **RBAC for Key Vault:** Access to the Key Vault is controlled using Role-Based Access Control (RBAC), following the principle of least privilege. The Managed Identity is granted only the "Key Vault Secrets User" role, which allows it to read secrets but not modify or delete them.

- **HTTPS Enabled by Default:** The Azure Container App is exposed via an HTTPS endpoint by default, ensuring that all communication between the client and the server is encrypted.

## Using with VS Code

1. Get the MCP configuration: `terraform output -json mcp_config_claude_code_hosted`
2. Add the configuration to `.vscode/mcp.json`
3. Press `Ctrl+Alt+I` to open GitHub Copilot Chat
4. Select "Agent" mode
5. Start using Terraform tools!

## Troubleshooting

### 401 Unauthorized Error

If you receive a "401 Unauthorized" error when trying to connect from VS Code:

- **Verify the API Key:** Check that the API key in `.vscode/mcp.json` matches `terraform output -raw api_key`
- **Check for Extra Characters:** Ensure no extra whitespace was copied
- **Restart VS Code:** Sometimes a simple restart resolves the issue

### Deployment Failures

- **Azure Login:** Ensure you're logged in with `az login`
- **Permissions:** Your account needs Contributor access and ability to create RBAC role assignments
- **Terraform State:** Run `terraform init -reconfigure` if you have state issues

### Key Vault Naming Conflicts

Azure Key Vaults have soft-delete enabled. If you encounter naming conflicts, manually purge the deleted vault:

```bash
az keyvault list-deleted
az keyvault purge --name <vault-name>
```

## Cleanup

Remove all Azure resources:
```bash
terraform destroy -auto-approve
```
