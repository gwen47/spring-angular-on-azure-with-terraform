output "api_url" {
  description = "Url of web api"
  value       = azurerm_linux_web_app.azure_three_tier_application.default_hostname
}
