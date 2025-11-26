# Container Apps infrastructure and deployment

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "mcp_logs" {
  name                = "mcp-logs-${random_string.suffix.result}"
  location            = azurerm_resource_group.mcp_rg.location
  resource_group_name = azurerm_resource_group.mcp_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Container App Environment
resource "azurerm_container_app_environment" "mcp_env" {
  name                       = "mcp-env"
  location                   = azurerm_resource_group.mcp_rg.location
  resource_group_name        = azurerm_resource_group.mcp_rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.mcp_logs.id
  tags                       = local.common_tags
}

# Container App - Initial deployment with public image
resource "azurerm_container_app" "mcp_app" {
  name                         = "terraform-mcp-server"
  container_app_environment_id = azurerm_container_app_environment.mcp_env.id
  resource_group_name          = azurerm_resource_group.mcp_rg.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.mcp_identity.id]
  }

  template {
    container {
      name   = "terraform-mcp"
      image  = "${azurerm_container_registry.mcp_acr.login_server}/terraform-mcp-server:latest"
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "PORT"
        value = "3000"
      }

      env {
        name        = "API_KEYS"
        secret_name = "api-keys-json"
      }

      # Legacy single key for backward compatibility
      env {
        name        = "API_KEY"
        secret_name = "api-key-default"
      }

      env {
        name  = "TFE_ADDRESS"
        value = var.tfe_address
      }

      env {
        name        = "TFE_TOKEN"
        secret_name = "tfe-token"
      }
    }

    min_replicas = 1
    max_replicas = 3
  }

  # JSON-encoded API keys for multi-user authentication
  secret {
    name = "api-keys-json"
    value = jsonencode({
      for user in var.api_key_users : user => random_password.api_key[user].result
    })
  }

  # Legacy single key for backward compatibility (uses first user's key)
  secret {
    name  = "api-key-default"
    value = random_password.api_key[var.api_key_users[0]].result
  }

  secret {
    name  = "tfe-token"
    value = var.tfe_token != "" ? var.tfe_token : "not-configured"
  }

  registry {
    server   = azurerm_container_registry.mcp_acr.login_server
    identity = azurerm_user_assigned_identity.mcp_identity.id
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
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
