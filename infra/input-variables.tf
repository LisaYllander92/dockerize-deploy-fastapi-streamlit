variable "resource-group-name" {
  default = "fullstack-python-rg"
  type = string
}

variable "location" {
    type = string
    default = "swedencentral"
}

variable "project_name" {
  default = "pokemon"
}

variable "acr_name" {
  default = "acrdemo"
}

variable "image_tag" {
  default = "latest"
}