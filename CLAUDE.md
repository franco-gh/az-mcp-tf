# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Terraform MCP (Model Context Protocol) Server deployment for Azure Container Apps. Deploys HashiCorp's terraform-mcp-server with native Streamable HTTP transport and API key authentication via Nginx sidecar.

## Architecture

```
Claude Code → Nginx (API key validation) → terraform-mcp-server (native HTTP)
                      ↓
              Key Vault (API key storage)
```

### Core Components

1. **Nginx + terraform-mcp-server** (single container with supervisord)
   - Nginx on port 8080 (external) validates API key
   - terraform-mcp-server on port 9000 (internal) with Streamable HTTP
   - Stateless mode for high availability (`MCP_SESSION_MODE=stateless`)
   - supervisord manages both processes

2. **API Key Authentication** (`nginx.conf`)
   - Validates `Authorization: Bearer <key>` or `X-API-Key` header
   - Health endpoint bypasses authentication
   - API key stored in Azure Key Vault

3. **Terraform Infrastructure** (split across multiple files):
   - `main.tf` - Resource Group, API key generation, random suffix, Managed Identity
   - `keyvault.tf` - Key Vault with RBAC authorization, API key secret
   - `container-registry.tf` - ACR with identity-based pull
   - `container-app.tf` - Container App configuration
   - `providers.tf` - Provider versions (azurerm, random)
   - `variables.tf` - Input variables (tfe_token, tfe_address, environment, owner)
   - `outputs.tf` - URLs, API key, MCP config

4. **Container** (`Dockerfile`)
   - Based on `hashicorp/terraform-mcp-server:latest`
   - Adds nginx, supervisord, gettext (envsubst)
   - API_KEY environment variable injected at startup

5. **CI/CD** (`.github/workflows/deploy.yml`)
   - Terraform Cloud integration
   - Triggers on push to main for Terraform, Dockerfile, or nginx.conf changes
   - Builds image via ACR, updates Container App

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
terraform output -raw mcp_endpoint
terraform output mcp_config_claude_code
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

### Testing
```bash
# Health check (no auth required)
curl https://<container-app-url>/health

# MCP endpoint (with API key)
API_KEY=$(terraform output -raw api_key)
curl -H "Authorization: Bearer $API_KEY" https://<container-app-url>/mcp
```

## Key Design Decisions

- **Native Streamable HTTP**: Uses HashiCorp's built-in transport (no custom Python wrapper)
- **Stateless Mode**: Enables horizontal scaling and high availability
- **API Key Auth via Nginx**: Simple, no token expiration, easy to manage
- **Key Vault RBAC**: Uses RBAC authorization instead of access policies
- **Managed Identity**: User-assigned identity for Key Vault and ACR access
- **Soft Delete**: Disabled for non-production, enabled for production via `environment` variable
- **Scaling**: 1-3 replicas, 1.0 CPU / 2Gi memory per container

## Environment Variables

Container App environment variables:
- `API_KEY`: API key for nginx authentication (from Key Vault)
- `TFE_ADDRESS`: Terraform Enterprise address (default: https://app.terraform.io)
- `TFE_TOKEN`: Terraform Enterprise API token (for private registries)

Internal (set by supervisord):
- `TRANSPORT_MODE`: `streamable-http`
- `TRANSPORT_HOST`: `127.0.0.1`
- `TRANSPORT_PORT`: `9000`
- `MCP_SESSION_MODE`: `stateless`

## Claude Code Configuration

Add to your `.vscode/mcp.json` or Claude Code settings:
```json
{
  "mcpServers": {
    "terraform": {
      "type": "sse",
      "url": "https://<container-app-fqdn>/mcp",
      "headers": {
        "Authorization": "Bearer <API_KEY>"
      }
    }
  }
}
```

Get your API key:
```bash
terraform output -raw api_key
```

## Troubleshooting

- **Key Vault naming conflicts**: Manually purge soft-deleted vaults with `az keyvault purge --name <vault-name>`
- **Container App failures**: Check logs with `az containerapp logs show --follow`
- **Permission errors**: Requires subscription Contributor access and ability to create RBAC role assignments
- **401 Unauthorized**: Check API key is correct and included in Authorization header
- **Health check fails**: Verify nginx and terraform-mcp-server processes are running
