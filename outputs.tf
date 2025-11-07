# Terraform outputs for deployment information

output "mcp_server_url" {
  value       = "https://${azurerm_container_app.mcp_app.latest_revision_fqdn}"
  description = "The public URL for the MCP server"
}

output "api_key" {
  value       = random_password.api_key.result
  sensitive   = true
  description = "API key for authenticating with the MCP server"
}

output "key_vault_name" {
  value       = azurerm_key_vault.mcp_vault.name
  description = "Name of the Azure Key Vault"
}

output "acr_login_server" {
  value       = azurerm_container_registry.mcp_acr.login_server
  description = "Login server URL for Azure Container Registry"
}

output "acr_name" {
  value       = azurerm_container_registry.mcp_acr.name
  description = "Name of the Azure Container Registry"
}

output "resource_group_name" {
  value       = azurerm_resource_group.mcp_rg.name
  description = "Name of the Azure Resource Group"
}

output "container_app_name" {
  value       = azurerm_container_app.mcp_app.name
  description = "Name of the Azure Container App"
}

# Claude Code MCP Configuration - Hosted on Azure
output "mcp_config_claude_code_hosted" {
  value = jsonencode({
    mcpServers = {
      terraform = {
        type = "sse"
        url  = "https://${azurerm_container_app.mcp_app.latest_revision_fqdn}/mcp/v1/sse"
        headers = {
          Authorization = "Bearer ${random_password.api_key.result}"
        }
      }
    }
  })
  sensitive   = true
  description = "Claude Code MCP configuration for hosted Azure deployment. Add this to your .vscode/mcp.json file."
}

# Claude Code MCP Configuration - Local Docker
output "mcp_config_claude_code_local" {
  value = jsonencode({
    mcpServers = {
      terraform = {
        type    = "docker"
        image   = "${azurerm_container_registry.mcp_acr.login_server}/terraform-mcp-server:latest"
        command = ["python3", "/usr/local/bin/mcp-sse-server.py"]
        env = {
          PORT        = "3000"
          API_KEY     = random_password.api_key.result
          TFE_ADDRESS = var.tfe_address
          TFE_TOKEN   = var.tfe_token
        }
      }
    }
  })
  sensitive   = true
  description = "Claude Code MCP configuration for local Docker deployment. Add this to your .vscode/mcp.json file."
}
