output "acr_login_server" {
    value = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "container_app_name" {
  value = azurerm_container_app.api.name
}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}