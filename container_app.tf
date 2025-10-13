# Log Analytics
resource "azurerm_log_analytics_workspace" "mcp_logs" {
  name                = "mcp-logs-${random_string.suffix.result}"
  location            = azurerm_resource_group.mcp_rg.location
  resource_group_name = azurerm_resource_group.mcp_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Container App Environment
resource "azurerm_container_app_environment" "mcp_env" {
  name                       = "mcp-env"
  location                   = azurerm_resource_group.mcp_rg.location
  resource_group_name        = azurerm_resource_group.mcp_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.mcp_logs.id
}

# Managed Identity for Container App
resource "azurerm_user_assigned_identity" "mcp_identity" {
  name                = "mcp-identity"
  location            = azurerm_resource_group.mcp_rg.location
  resource_group_name = azurerm_resource_group.mcp_rg.name
}

# Grant identity access to Key Vault secrets
resource "azurerm_role_assignment" "identity_kv_reader" {
  scope                = azurerm_key_vault.mcp_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.mcp_identity.principal_id
}

# Container App - Initial deployment with public image
resource "azurerm_container_app" "mcp_app" {
  name                         = "terraform-mcp-server"
  container_app_environment_id = azurerm_container_app_environment.mcp_env.id
  resource_group_name          = azurerm_resource_group.mcp_rg.name
  revision_mode                = "Single"

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.mcp_identity.id]
  }

  template {
    container {
      name   = "terraform-mcp"
      image  = "${azurerm_container_registry.mcp_acr.login_server}/terraform-mcp-server@${data.local_file.image_digest.content}"
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "PORT"
        value = "3000"
      }

      env {
        name        = "API_KEY"
        secret_name = "api-key"
      }
    }

    min_replicas = 1
    max_replicas = 3
  }

  secret {
    name  = "api-key"
    value = random_password.api_key.result
  }

  registry {
    server               = azurerm_container_registry.mcp_acr.login_server
    username             = azurerm_container_registry.mcp_acr.admin_username
    password_secret_name = "registry-password"
  }

  secret {
    name  = "registry-password"
    value = azurerm_container_registry.mcp_acr.admin_password
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = {
    environment = "production"
    application = "terraform-mcp-server"
  }

  depends_on = [
    azurerm_role_assignment.identity_kv_reader
  ]
}