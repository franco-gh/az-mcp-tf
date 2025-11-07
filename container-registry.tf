# Azure Container Registry for storing Docker images

resource "azurerm_container_registry" "mcp_acr" {
  name                = "mcpacr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.mcp_rg.name
  location            = azurerm_resource_group.mcp_rg.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.common_tags
}

# Role assignment for Container App identity to pull from ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.mcp_acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.mcp_identity.principal_id
}
