resource "azurerm_container_registry" "acr" {
  name                = "${var.acr_name}${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
  admin_enabled       = true
}

# full dependency graph for the acr
# terraform apply -auto-approve -target=azurerm_container_registry.acr