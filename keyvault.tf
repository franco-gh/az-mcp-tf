# Generate API Key
resource "random_password" "api_key" {
  length  = 32
  special = true
  override_special = "-_"
}

# Key Vault with proper configuration
resource "azurerm_key_vault" "mcp_vault" {
  name                = "mcp-kv-${random_string.suffix.result}"
  location            = azurerm_resource_group.mcp_rg.location
  resource_group_name = azurerm_resource_group.mcp_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable soft delete and purge protection
  soft_delete_retention_days = 7
  purge_protection_enabled   = false  # Set to false for easier testing

  # Enable RBAC authorization (alternative to access policies)
  enable_rbac_authorization = true
}

# Assign Key Vault Administrator role to current user
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.mcp_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store API key in Key Vault
resource "azurerm_key_vault_secret" "api_key" {
  name         = "mcp-api-key"
  value        = random_password.api_key.result
  key_vault_id = azurerm_key_vault.mcp_vault.id

  # Ensure role assignment is complete before creating secret
  depends_on = [azurerm_role_assignment.kv_admin]
}