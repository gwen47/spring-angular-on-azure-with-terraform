terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.108.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      recover_soft_deleted_key_vaults = true
      purge_soft_delete_on_destroy    = true
    }
  }
}

resource "random_id" "prefix" {
  byte_length = 3
  prefix      = "s" # we add a letter to prevent errors with those resources whose name can't begin with a number
}

data "azurerm_resource_group" "azure_three_tier_application" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "azure_three_tier_application" {
  count    = var.create_resource_group ? 1 : 0
  name     = "${local.resource_prefix}-tf-api-azure_three_tier_application"
  location = var.resource_group_location
}

locals {
  resource_prefix         = lower(random_id.prefix.hex)
  resource_group_name     = var.create_resource_group ? azurerm_resource_group.azure_three_tier_application[0].name : data.azurerm_resource_group.azure_three_tier_application[0].name
  resource_group_location = var.create_resource_group ? azurerm_resource_group.azure_three_tier_application[0].location : data.azurerm_resource_group.azure_three_tier_application[0].location
  app_service_name        = "${local.resource_prefix}-api"
}


data "azurerm_client_config" "current" {}

#Keyvault
module "kv" {
  source              = "./modules/keyvault"
  resource_prefix     = local.resource_prefix
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
}

#App Service
module "api" {
  source                      = "./modules/api"
  resource_prefix             = local.resource_prefix
  app_service_name            = local.app_service_name
  resource_group_name         = local.resource_group_name
  location                    = local.resource_group_location
  db_name                     = var.db_name
  postgresql_admin_username   = var.postgresql_admin_username
  postgresql_admin_password   = var.postgresql_admin_password
  postgresql_storage          = var.postgresql_storage
  postgresql_storage_tier     = var.postgresql_storage_tier
  container_registry_server   = var.container_registry_server
  container_registry_username = var.container_registry_username
  container_registry_password = var.container_registry_password
  container_image_name        = var.container_image_name
  keyvault_id                 = module.kv.keyvault_id
  keyvault_uri                = module.kv.keyvault_uri
  depends_on = [
    module.kv
  ]
}


