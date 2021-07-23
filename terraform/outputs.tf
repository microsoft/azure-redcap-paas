output "resource_group_name" {
  value = azurerm_resource_group.redcap.name
}

output "app_service_name" {
  value = azurerm_app_service.redcap.name
}

output "deploy_source" {
  value = "az webapp deployment source config --branch ${var.branch} --manual-integration --name ${azurerm_app_service.redcap.name} --repo-url ${var.repoURL} --resource-group ${azurerm_resource_group.redcap.name}"
}

output "deploy_source_sub" {
  value     = var.subscription_id
  sensitive = true
}

output "registration_token" {
  value     = azurerm_virtual_desktop_host_pool.redcap.registration_info[0].token
  sensitive = true
}

output "vnet_id" {
  value = azurerm_virtual_network.redcap.id
}