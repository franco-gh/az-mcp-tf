# Terraform outputs for deployment information

output "mcp_server_url" {
  value       = "https://${azurerm_container_app.mcp_app.ingress[0].fqdn}"
  description = "The public URL for the MCP server"
}

output "mcp_endpoint" {
  value       = "https://${azurerm_container_app.mcp_app.ingress[0].fqdn}/mcp"
  description = "The MCP endpoint URL for Streamable HTTP transport"
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

# API Key for authentication
output "api_key" {
  value       = random_password.api_key.result
  sensitive   = true
  description = "API key for authenticating with the MCP server"
}

# Claude Code MCP Configuration - ready to use
output "mcp_config_claude_code" {
  value = jsonencode({
    mcpServers = {
      terraform = {
        type = "sse"
        url  = "https://${azurerm_container_app.mcp_app.ingress[0].fqdn}/mcp"
        headers = {
          Authorization = "Bearer <API_KEY>"
        }
      }
    }
  })
  description = <<-EOT
    Claude Code MCP configuration for hosted Azure deployment.

    To get your API key:
      terraform output -raw api_key

    Replace <API_KEY> with the actual value in your settings.json or mcp.json file.
  EOT
}
