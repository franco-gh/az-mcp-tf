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

# Container App with Nginx + terraform-mcp-server (native Streamable HTTP)
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

      # API key for nginx authentication (injected at startup)
      env {
        name        = "API_KEY"
        secret_name = "api-key"
      }

      # HCP Terraform / TFE configuration for private registries
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

  secret {
    name  = "tfe-token"
    value = var.tfe_token != "" ? var.tfe_token : "not-configured"
  }

  secret {
    name                = "api-key"
    key_vault_secret_id = azurerm_key_vault_secret.api_key.id
    identity            = azurerm_user_assigned_identity.mcp_identity.id
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
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags

  depends_on = [
    azurerm_role_assignment.identity_kv_reader,
    azurerm_key_vault_secret.api_key
  ]
}
