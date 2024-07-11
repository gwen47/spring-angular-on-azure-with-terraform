############################################

# Variables

############################################

resource "random_string" "pgs-username" {
  length    = 10
  special   = false
  numeric   = false
  min_lower = 1
}

resource "random_string" "pgs-password" {
  length      = 10
  min_lower   = 1
  min_upper   = 1
  min_special = 1
  min_numeric = 1
}

resource "random_string" "pgs-db-name" {
  length  = 10
  special = false
  numeric = false
  upper   = false
}


locals {
  dns_label_prefix          = "${var.resource_prefix}-postgresql"
  connection_string         = "jdbc:postgresql://${azurerm_postgresql_flexible_server.azure_three_tier_application.fqdn}:5432/${local.postgresql_db_name}?sslmode=require"
  container_registry_server = "https://${var.container_registry_server}"
  postgresql_admin_username = var.postgresql_admin_username == "" ? random_string.pgs-username.result : var.postgresql_admin_username
  postgresql_admin_password = var.postgresql_admin_password == "" ? random_string.pgs-password.result : var.postgresql_admin_password
  postgresql_db_name        = var.db_name == "" ? "${random_string.pgs-db-name.result}-azure_three_tier_application-api" : var.db_name
}

# Get the current client configuration
data "azurerm_client_config" "current" {}

############################################

# Network

############################################

# App VNet
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
resource "azurerm_virtual_network" "azure_three_tier_application" {
  name                = "${local.dns_label_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

# App subnet
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
resource "azurerm_subnet" "azure_three_tier_application" {
  name                              = "${local.dns_label_prefix}-app-subnet"
  address_prefixes                  = ["10.0.1.0/24"]
  virtual_network_name              = azurerm_virtual_network.azure_three_tier_application.name
  resource_group_name               = var.resource_group_name
  private_endpoint_network_policies = "Disabled"
  # If enabled, Route table and Network Security Groups should be configured

  # Adding the required delegation for Azure App Service
  delegation {
    name = "appServiceDelegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Database subnet
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet
resource "azurerm_subnet" "private_subnet_azure_three_tier_application" {
  name                 = "${local.dns_label_prefix}-subnet"
  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.azure_three_tier_application.name
  resource_group_name  = var.resource_group_name

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Private DNS zone
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone
resource "azurerm_private_dns_zone" "azure_three_tier_application" {
  name                = "${local.dns_label_prefix}.private.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

# Link VNet to private DNS zone
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link
resource "azurerm_private_dns_zone_virtual_network_link" "azure_three_tier_application" {
  name                  = "${local.dns_label_prefix}-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.azure_three_tier_application.name
  virtual_network_id    = azurerm_virtual_network.azure_three_tier_application.id
  resource_group_name   = var.resource_group_name
  depends_on            = [azurerm_subnet.private_subnet_azure_three_tier_application]
}


############################################

# Database

############################################

# Postgresql Flexible Server
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server
resource "azurerm_postgresql_flexible_server" "azure_three_tier_application" {
  name                          = "${var.resource_prefix}-postgresql"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "12"
  delegated_subnet_id           = azurerm_subnet.private_subnet_azure_three_tier_application.id
  private_dns_zone_id           = azurerm_private_dns_zone.azure_three_tier_application.id
  public_network_access_enabled = false
  administrator_login           = local.postgresql_admin_username
  administrator_password        = local.postgresql_admin_password
  zone                          = "1"

  storage_mb   = var.postgresql_storage
  storage_tier = var.postgresql_storage_tier

  # smallest General Purpose
  sku_name   = "GP_Standard_D2ds_v4" # https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-compute#compute-tiers-vcores-and-server-types
  depends_on = [azurerm_private_dns_zone_virtual_network_link.azure_three_tier_application]
}

# Database on Postgresql Flexible Server
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_database
resource "azurerm_postgresql_flexible_server_database" "azure_three_tier_application" {
  name      = local.postgresql_db_name
  server_id = azurerm_postgresql_flexible_server.azure_three_tier_application.id
  collation = "en_US.utf8"
  charset   = "utf8"

  # prevent the possibility of accidental data loss
  # lifecycle {
  #   prevent_destroy = true
  # }
}

############################################

# App service

############################################

# App service plan
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
# https://learn.microsoft.com/en-us/cli/azure/appservice/plan?view=azure-cli-latest
resource "azurerm_service_plan" "azure_three_tier_application" {
  name                = "azure_three_tier_application_service_plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# App service
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app
resource "azurerm_linux_web_app" "azure_three_tier_application" {
  name                          = "${var.resource_prefix}-api"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  service_plan_id               = azurerm_service_plan.azure_three_tier_application.id
  public_network_access_enabled = true

  site_config {

    application_stack {
      docker_image_name   = var.container_image_name
      docker_registry_url = local.container_registry_server
    }
  }

  # Environment variables
  # https://learn.microsoft.com/en-us/azure/app-service/configure-common?tabs=portal#configure-app-settings
  app_settings = {
    "SPRING_PROFILES_ACTIVE"            = "prod,swagger"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
    WEBSITE_ENABLE_SYNC_UPDATE_SITE     = "true"
    SPRING_DATASOURCE_URL               = "@Microsoft.KeyVault(SecretUri=${var.keyvault_uri}secrets/db-connection-string)"
    SPRING_DATASOURCE_USERNAME          = "@Microsoft.KeyVault(SecretUri=${var.keyvault_uri}secrets/db-username)@${azurerm_postgresql_flexible_server.azure_three_tier_application.fqdn}"
    SPRING_DATASOURCE_PASSWORD          = "@Microsoft.KeyVault(SecretUri=${var.keyvault_uri}secrets/db-password)"
    DB_USERNAME                         = "@Microsoft.KeyVault(SecretUri=${var.keyvault_uri}secrets/db-username)"
    DB_PASSWORD                         = "@Microsoft.KeyVault(SecretUri=${var.keyvault_uri}secrets/db-password)"
    KEY_VAULT_URL                       = var.keyvault_uri
  }

  identity {
    # Identity is managed by Azure and will be assigned at creation time
    type = "SystemAssigned"
  }
}

# Connect App service to subnet in VNet
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_virtual_network_swift_connection
resource "azurerm_app_service_virtual_network_swift_connection" "azure_three_tier_application" {
  app_service_id = azurerm_linux_web_app.azure_three_tier_application.id
  subnet_id      = azurerm_subnet.azure_three_tier_application.id
}

############################################

# KeyVault

############################################

# We grant access to keyvault to App Service
resource "azurerm_key_vault_access_policy" "azure_three_tier_application_app" {
  key_vault_id = var.keyvault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.azure_three_tier_application.identity[0].principal_id

  secret_permissions = [
    "Get", "Set", "List", "Delete", "Purge"
  ]
}

# Add KeyVault entries
locals {
  kv_entries = {
    "acr-username"         = var.container_registry_username
    "acr-password"         = var.container_registry_password
    "db-connection-string" = local.connection_string
    "db-username"          = local.postgresql_admin_username
    "db-password"          = local.postgresql_admin_password
  }
}

# Add KeyVault entries using a loop
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret
resource "azurerm_key_vault_secret" "azure_three_tier_application" {
  for_each     = local.kv_entries
  key_vault_id = var.keyvault_id
  name         = each.key
  value        = each.value
}
