resource "azurerm_service_plan" "asp" {
  name                = "${var.project_name}-asp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "webapp" {
  name                = "${var.project_name}-webapp-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    application_stack {
      docker_image_name   = "frontend:${var.image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
    container_registry_use_managed_identity = true
  }
  identity { type = "SystemAssigned" }

  app_settings = {
    "WEBSITES_PORT"    = "8501"
    "DOCKER_ENABLE_CI" = "true" # makes docker pull everytime we push to acr as acr will alert app services
  }
}