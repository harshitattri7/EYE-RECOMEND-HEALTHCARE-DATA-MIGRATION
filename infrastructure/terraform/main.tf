terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.30.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-eyerecommend-tfstate"
    storage_account_name = "steyerecommendtfstate"
    container_name       = "tfstate"
    key                  = "migration.prod.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

resource "azurerm_resource_group" "rg_migration" {
  name     = "rg-${var.project_name}-${var.environment}-${var.azure_region}"
  location = var.azure_region

  tags = {
    Project     = "Eye Recommend Healthcare Migration"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Compliance  = "HIPAA-HITRUST"
    CostCenter  = "Data-Engineering-Migration"
  }
}
