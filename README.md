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


Skapa paket:
uv init --no-package --python 3.13

uv init --package backend
uv init --package frontend


- lägg till dependencis i frontend och backend (pyproject)
- uv sync --all-packages

Kommando för uvicorn? - spinna upp webservern för fastapi
uv run uvicorn api:app --reload

localhost:8000


kolla backend:
uv run unvicorn api:app --reload (api.py + app=FrastAPI)
http://127.0.0.1:8000/pokemon/stats

kolla frontend:
uv run streamlit run dashboard.py

# Dockerize med docker:
öppna docker desktop
1. skapa backend.dockerfile och frontend.dockerfile
Backend:
# Officiell basimage från python (slimmad version)
FROM python:3.13-slim

# Kopierar allt från backend folder till /app folder, som skapas om den inte redan existerade
COPY backend/ /app/

# Installear uv
RUN pip install --no-cache-dir uv

# Byter directory till /app
WORKDIR /app

# Installerar alla dependencies från pyproject.toml utan dev packages
RUN uv sync --no-dev

# Byter directory till vart vi har api.py
WORKDIR /app/src/backend

# Kör kommandon (0.0.0.0 -> accepterar connections från lokal maskin och external)
CMD [ "uv" , "run", "uvicorn", "api:app", "--host", "0.0.0.0"]

docker-compose (backend):
services:
  backend:
    container_name: backend
    build:
      context: . # kommer se allt som finns i rotmappen (där docker-compose filer ligger)
      dockerfile: dockerfiles/backend.dockerfile
    ports:
      - "8000:8000"

testa att det funkar och bygg image:
docker compose up -d

i gitbash: (ta bort onödigt men ha kvar och förklara kommandon)
lisay@Lisas MINGW64 ~
$ docker ps
CONTAINER ID   IMAGE                                        COMMAND                  CREATED         STATUS         PORTS                                         NAMES
ca8623e379f9   dockerize-deploy-fastapi-streamlit-backend   "uv run uvicorn api:…"   6 seconds ago   Up 3 seconds   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp   backend

lisay@Lisas MINGW64 ~
$ ^C

lisay@Lisas MINGW64 ~
$ docker exec -it ca8623e379f9 bash
root@ca8623e379f9:/app/src/backend#
root@ca8623e379f9:/app/src/backend# cat api.py (concatinat)
uv pip freeze
Ctrl + d - exit

# jump in to an existing running container
docker exec -it container_name bash

# if container is dead - spin up a new one interactively
docker run -it image_name bash

frontend.dockerfile:
# Officiell basimage från python (slimmad version)
FROM python:3.13-slim 

# Kopierar allt från frontend folder till /app folder, som skapas om den inte redan existerade
COPY frontend/ /app/ 

# Installear uv
RUN pip install --no-cache-dir uv 

# Byter directory till /app
WORKDIR /app 

# Installerar alla dependencies från pyproject.toml utan dev packages
RUN uv sync --no-dev 

# Byter directory till vart vi har api.py
WORKDIR /app/src/frontend

# Kör kommandon (0.0.0.0 -> accepterar connections från lokal maskin och external)
CMD [ "uv" , "run", "streamlit", "run", "dashboard.py", "--server.address", "0.0.0.0"] 

uppdatera dashboard:
import streamlit as st
import httpx 
import os

# os.getenv försöker hämtar miljövariabel BACKEND_URL, om den inte finns - default andra variabeln (http...)
BASE_URL = os.getenv("BACKEND_URL", "http://127.0.0.1:8000")

def main():
    st.markdown("# PokeDash")

    stats = httpx.get(f"{BASE_URL}/pokemon/stats", timeout=30).json()
    st.dataframe(stats)

if __name__ == "__main__":
    main()
