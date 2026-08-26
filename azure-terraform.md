# set upp Azure network and test

main.tf:
# Source: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = " ~> 5.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "test_terraform-rg" {
  name     = "test_terraform"
  location = "swedencentral"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "example" {
  name                = "example-network"
  resource_group_name = azurerm_resource_group.test_terraform-rg.name
  location            = azurerm_resource_group.test_terraform-rg.location
  address_space       = ["10.0.0.0/16"]
}

1. terraform init 
2. terraform validate (optional)
3. terraform plan
4. terraform apply --auto-approve 
5. terraform destory -auto-approve

# FastApi med streamlit
- backend and fronend decoupled
Docker(backend (Python) - API (Fastapi)) <-requests->  Docker(fronend (streamlit)) -> Deploy (till molnet)



