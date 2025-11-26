# Core infrastructure resources

# Common tags for all resources
locals {
  common_tags = {
    environment = var.environment
    application = "terraform-mcp-server"
    managed_by  = "terraform"
    owner       = var.owner
  }
}

# Resource Group
resource "azurerm_resource_group" "mcp_rg" {
  name     = "terraform-mcp-rg"
  location = "East US"
  tags     = local.common_tags
}

# Generate API Key per user
resource "random_password" "api_key" {
  for_each         = toset(var.api_key_users)
  length           = 32
  special          = true
  override_special = "-_"
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Managed Identity for Container App
resource "azurerm_user_assigned_identity" "mcp_identity" {
  name                = "mcp-identity"
  location            = azurerm_resource_group.mcp_rg.location
  resource_group_name = azurerm_resource_group.mcp_rg.name
  tags                = local.common_tags
}
