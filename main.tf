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

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
