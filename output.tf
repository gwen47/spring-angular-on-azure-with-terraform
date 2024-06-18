output "resource_group_name" {
  value       = local.resource_group_name
  description = "The resource group where resources have been created"
}

output "api_url" {
  value       = module.api.api_url
  description = "API endpoint address"
}






