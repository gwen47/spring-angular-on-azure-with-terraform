output "keyvault_id" {
  value = azurerm_key_vault.azure_three_tier_application.id
}

output "keyvault_uri" {
  value = azurerm_key_vault.azure_three_tier_application.vault_uri
}
