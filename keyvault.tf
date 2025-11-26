# Key Vault configuration for secure secret storage

# Key Vault with RBAC authorization
resource "azurerm_key_vault" "mcp_vault" {
  name                = "mcp-kv-${random_string.suffix.result}"
  location            = azurerm_resource_group.mcp_rg.location
  resource_group_name = azurerm_resource_group.mcp_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable soft delete and purge protection
  soft_delete_retention_days = 7
  purge_protection_enabled   = var.environment == "production" ? true : false

  # Enable RBAC authorization (alternative to access policies)
  enable_rbac_authorization = true

  tags = local.common_tags
}

# Assign Key Vault Administrator role to current user
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.mcp_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store API keys in Key Vault (one per user)
resource "azurerm_key_vault_secret" "api_keys" {
  for_each     = toset(var.api_key_users)
  name         = "mcp-api-key-${each.key}"
  value        = random_password.api_key[each.key].result
  key_vault_id = azurerm_key_vault.mcp_vault.id

  # Ensure role assignment is complete before creating secret
  depends_on = [azurerm_role_assignment.kv_admin]
}

# Grant managed identity access to Key Vault secrets
resource "azurerm_role_assignment" "identity_kv_reader" {
  scope                = azurerm_key_vault.mcp_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.mcp_identity.principal_id
}
