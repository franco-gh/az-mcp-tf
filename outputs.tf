# Outputs
output "mcp_server_url" {
  value = "https://${azurerm_container_app.mcp_app.latest_revision_fqdn}"
}

output "api_key" {
  value     = random_password.api_key.result
  sensitive = true
}

output "key_vault_name" {
  value = azurerm_key_vault.mcp_vault.name
}

output "acr_login_server" {
  value = azurerm_container_registry.mcp_acr.login_server
}

output "acr_name" {
  value = azurerm_container_registry.mcp_acr.name
}