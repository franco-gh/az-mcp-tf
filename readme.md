# Terraform MCP Server - Azure Deployment

This project provides a secure and automated way to deploy the `terraform-mcp-server` to Azure Container Apps. It uses a Python-based Server-Sent Events (SSE) wrapper to ensure compatibility with clients like the GitHub Copilot Chat extension in VS Code, which require SSE for communication.

The deployment is orchestrated using a PowerShell script that automates the entire process, from setting up the Azure infrastructure with Terraform to building and deploying the containerized application.

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

- **Automated Deployment:** The entire deployment process is automated using a single PowerShell script.
- **Secure by Design:** It leverages Azure Key Vault for storing sensitive information like API keys and uses Managed Identities for secure access between Azure resources.
- **Scalable:** The application is deployed to Azure Container Apps, a serverless container hosting service that can automatically scale based on demand.
- **Easy to Use:** Once deployed, it can be easily configured in VS Code for use with GitHub Copilot Chat.

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

The entire deployment process is automated with the `deploy.ps1` PowerShell script.

1. **Open a PowerShell or Command Prompt:** Ensure you are in the root directory of the project.
2. **Run the deployment script:**
   ```powershell
   ./deploy.ps1
   ```

### What the Script Does

The `deploy.ps1` script performs the following actions:

1.  **Prerequisite Checks:** Verifies that both Terraform and the Azure CLI are installed and available in your PATH.
2.  **Clean Up Key Vaults:** Checks for and purges any soft-deleted Key Vaults with the same name to prevent naming conflicts during deployment.
3.  **Deploy Infrastructure:** Runs `terraform init` and `terraform apply` to create all the necessary Azure resources, including the Key Vault, Container Registry, and Container App Environment.
4.  **Build and Push Docker Image:** Uses the Azure Container Registry (`az acr build`) to build the Docker image from the `Dockerfile` and push it to your private registry.
5.  **Update Container App:** Updates the Azure Container App to use the newly built container image from your Azure Container Registry.
6.  **Create VS Code Configuration:** Generates a `.vscode/mcp.json` file with the connection details for your new `terraform-mcp-server` instance, including the server URL and the API key.

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

1. Open VS Code in this directory
2. The deployment creates `.vscode/mcp.json` with your configuration
3. Press `Ctrl+Alt+I` to open GitHub Copilot Chat
4. Select "Agent" mode
5. Start using Terraform tools!

## Troubleshooting

### 401 Unauthorized Error

If you receive a "401 Unauthorized" error when trying to connect from VS Code, it means that the API key is incorrect.

-   **Verify the API Key:** Double-check that the API key in your `.vscode/mcp.json` file matches the one output by the `deploy.ps1` script.
-   **Check for Extra Characters:** Ensure that you haven't accidentally copied any extra characters or whitespace.
-   **Restart VS Code:** Sometimes, a simple restart of VS Code can resolve the issue.

### Deployment Failures

If the `deploy.ps1` script fails, here are a few things to check:

-   **Azure Login:** Make sure you are logged in to the correct Azure account by running `az login`.
-   **Permissions:** Ensure that your account has the necessary permissions to create resources in the target subscription.
-   **Terraform State:** If a previous deployment failed, you might have a corrupt or locked Terraform state file. You can try running `terraform init -reconfigure` to reinitialize the backend.

### Key Vault Naming Conflicts

The `deploy.ps1` script attempts to purge any soft-deleted Key Vaults with the same name. However, if you still encounter a naming conflict, you can manually purge the Key Vault from the Azure Portal.

## Cleanup

Remove all Azure resources:
```powershell
terraform destroy -auto-approve
```
