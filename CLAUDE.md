# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Terraform MCP (Model Context Protocol) Server deployment for Azure Container Apps. Deploys HashiCorp's terraform-mcp-server wrapped in an SSE (Server-Sent Events) interface for VS Code GitHub Copilot integration.

## Architecture

```
VS Code/Copilot → Azure Container App (Python SSE Wrapper) → terraform-mcp-server (subprocess)
                         ↓
                 Managed Identity → Key Vault (API Key)
```

### Core Components

1. **MCP SSE Server** (`mcp-sse-server.py`)
   - Python aiohttp server wrapping terraform-mcp-server stdio interface
   - Implements SSE protocol with Bearer/X-API-Key authentication
   - Rate limiting: 10 requests per IP per 60-second window
   - Spawns and manages terraform-mcp-server subprocess per connection
   - Endpoints: `/health`, `/mcp/v1/sse` (POST), `/` (info)

2. **Terraform Infrastructure** (split across multiple files):
   - `main.tf` - Resource Group, API key generation, random suffix, Managed Identity
   - `keyvault.tf` - Key Vault with RBAC authorization, secret storage
   - `container-registry.tf` - ACR with identity-based pull
   - `container-app.tf` - Container App, Log Analytics, environment config
   - `providers.tf` - Provider versions and Azure config
   - `variables.tf` - Input variables (tfe_token, tfe_address, environment, owner)
   - `outputs.tf` - URLs, credentials, MCP config JSON for Claude Code

3. **Container** (`Dockerfile`)
   - Based on `hashicorp/terraform-mcp-server:latest`
   - Adds Python 3, aiohttp, aiohttp-sse
   - Runs as non-root user (mcp:1000)
   - Built-in health check on port 3000

4. **CI/CD** (`.github/workflows/deploy.yml`)
   - Triggers on push to main for mcp-sse-server.py, Dockerfile, or workflow changes
   - Discovers resources by application tag, builds image via ACR, updates Container App

## Common Commands

### Deployment
```bash
# Initial deployment
terraform init
terraform apply -auto-approve

# Build and push Docker image
ACR_NAME=$(terraform output -raw acr_name)
az acr build --registry $ACR_NAME --image terraform-mcp-server:latest --file Dockerfile .

# Update Container App with new image
CONTAINER_APP=$(terraform output -raw container_app_name)
RG=$(terraform output -raw resource_group_name)
ACR_SERVER=$(terraform output -raw acr_login_server)
az containerapp update --name $CONTAINER_APP --resource-group $RG --image "$ACR_SERVER/terraform-mcp-server:latest"
```

### Terraform Operations
```bash
terraform init
terraform plan
terraform apply
terraform destroy -auto-approve

# View outputs
terraform output
terraform output -raw api_key
terraform output -json mcp_config_claude_code_hosted  # For VS Code config
```

### Manual Azure Operations
```bash
# Build and push Docker image
az acr build --registry <ACR_NAME> --image "terraform-mcp-server:latest" --file Dockerfile .

# Update Container App
az containerapp update --name terraform-mcp-server --resource-group terraform-mcp-rg --image "<ACR_LOGIN_SERVER>/terraform-mcp-server:latest"

# View logs
az containerapp logs show --name terraform-mcp-server --resource-group terraform-mcp-rg --follow

# Purge soft-deleted Key Vaults (if naming conflicts)
az keyvault list-deleted
az keyvault purge --name mcp-kv-<suffix>
```

### Local Development
```bash
PORT=3000 API_KEY=test python3 mcp-sse-server.py
# Requires terraform-mcp-server binary in PATH
```

### Testing
```bash
# Health check
curl https://<container-app-url>/health

# SSE endpoint
curl -X POST -H "Authorization: Bearer <api-key>" https://<container-app-url>/mcp/v1/sse
```

## Key Design Decisions

- **Key Vault RBAC**: Uses RBAC authorization instead of access policies
- **Managed Identity**: User-assigned identity for Key Vault and ACR access
- **Soft Delete**: Disabled for non-production, enabled for production via `environment` variable
- **Scaling**: 1-3 replicas, 1.0 CPU / 2Gi memory per container
- **Image lifecycle**: Terraform ignores image changes after initial deployment (managed by CI/CD)

## Environment Variables

- `PORT`: HTTP server port (default: 3000)
- `API_KEY`: Required for authentication (from Key Vault)
- `TFE_ADDRESS`: Terraform Enterprise address (default: https://app.terraform.io)
- `TFE_TOKEN`: Terraform Enterprise API token (for private registries)

## VS Code Configuration

Generated config in `.vscode/mcp.json`:
```json
{
  "servers": {
    "terraform": {
      "url": "https://<container-app-fqdn>/mcp/v1/sse",
      "headers": { "Authorization": "Bearer <api-key>" },
      "type": "sse"
    }
  }
}
```

## Troubleshooting

- **Key Vault naming conflicts**: Manually purge soft-deleted vaults with `az keyvault purge --name <vault-name>`
- **Container App failures**: Check logs with `az containerapp logs show --follow`
- **Permission errors**: Requires subscription Contributor access and ability to create RBAC role assignments
