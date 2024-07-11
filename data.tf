
data "azurerm_resource_group" "azure_three_tier_application" {
  count = var.create_resource_group ? 0 : 1
  name  = var.resource_group_name
}

data "azurerm_client_config" "current" {}
