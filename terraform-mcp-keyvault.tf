# Terraform configuration with proper Key Vault setup
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Data source for current Azure configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "mcp_rg" {
  name     = "terraform-mcp-rg"
  location = "East US"
}

# Generate API Key
resource "random_password" "api_key" {
  length  = 32
  special = true
  override_special = "-_"
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
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

# Azure Container Registry
resource "azurerm_container_registry" "mcp_acr" {
  name                = "mcpacr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.mcp_rg.name
  location            = azurerm_resource_group.mcp_rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

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
      # Start with public image, will be updated by post-deployment script
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
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

# Output to indicate post-deployment steps needed
output "post_deployment_required" {
  value = "true"
  description = "Run deploy.ps1 to complete the container image build and deployment"
}

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