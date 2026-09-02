# FastAPI + Streamlit → Docker → Azure

![](image.png)

Backend (FastAPI) och frontend (Streamlit) som separata, frikopplade delar. De pratar med varandra via HTTP-requests, körs i varsin Docker-container, och deployas till Azure.

```
Backend (FastAPI, Docker) <--requests--> Frontend (Streamlit, Docker) --> Deploy till Azure
```

## 1. Skapa projektstruktur (lokalt, VS Code)

```bash
uv init --no-package --python 3.13
uv init --package backend
uv init --package frontend
```

- Lägg till dependencies i respektive `pyproject.toml` (backend/frontend var för sig)
- Installera allt:
```bash
uv sync --all-packages
```

## 2. Kör lokalt (utan Docker) – för att testa innan containerisering

**Backend:**
```bash
uv run uvicorn api:app --reload
```
Startar FastAPI-servern på `http://127.0.0.1:8000`. Testa t.ex. `http://127.0.0.1:8000/pokemon/stats`.

**Frontend:**
```bash
uv run streamlit run dashboard.py
```

## 3. Dockerize

Öppna Docker Desktop (måste vara igång).

**`backend.dockerfile`:**
```dockerfile
FROM python:3.13-slim

COPY backend/ /app/

RUN pip install --no-cache-dir uv

WORKDIR /app
RUN uv sync --no-dev

WORKDIR /app/src/backend
CMD ["uv", "run", "uvicorn", "api:app", "--host", "0.0.0.0"]
```

**`frontend.dockerfile`:**
```dockerfile
FROM python:3.13-slim

COPY frontend/ /app/

RUN pip install --no-cache-dir uv

WORKDIR /app
RUN uv sync --no-dev

WORKDIR /app/src/frontend
CMD ["uv", "run", "streamlit", "run", "dashboard.py", "--server.address", "0.0.0.0"]
```

`--host 0.0.0.0` / `--server.address 0.0.0.0` gör att servern accepterar anrop både lokalt och utifrån containern.

**`docker-compose.yaml`:**
```yaml
services:
  backend:
    container_name: backend
    build:
      context: .
      dockerfile: dockerfiles/backend.dockerfile
    ports:
      - "8000:8000"

  frontend:
    container_name: frontend
    build:
      context: .
      dockerfile: dockerfiles/frontend.dockerfile
    ports:
      - "8501:8501"
    environment:
      BACKEND_URL: http://backend:8000
```

`context: .` innebär att build-processen ser hela rotmappen (där `docker-compose.yaml` ligger).

**Bygg och starta:**
```bash
docker compose up -d
```

## 4. Koppla frontend mot backend

I `dashboard.py`:
```python
import os

# Läser miljövariabeln BACKEND_URL, annars fallback till localhost
BASE_URL = os.getenv("BACKEND_URL", "http://127.0.0.1:8000")
```

Detta gör att samma kod funkar både lokalt (fallback) och i Docker (miljövariabeln sätts i `docker-compose.yaml`).

## 5. Användbara Docker-kommandon

```bash
docker ps                          # lista körande containers
docker exec -it <container_id> bash   # hoppa in i en körande container
docker run -it <image_name> bash      # starta en ny container interaktivt (om ingen redan kör)
```

Inne i en container, t.ex.:
```bash
cat api.py        # visa filinnehåll
uv pip freeze      # lista installerade paket
exit               # (Ctrl+D) lämna containern
```

## 6. Azure Container Registry (ACR)

**I Azure Portal:**
1. Skapa en resource group
2. Skapa ett Container Registry
3. Under **"Access keys"** → aktivera **Admin user**, kopiera **Login server**

**I `docker-compose.yaml`**, lägg till image-namn (byggs mot ditt registry):
```yaml
services:
  backend:
    image: <login-server>/backend:v1
  frontend:
    image: <login-server>/frontend:v1
```

**I terminalen:**
```bash
az acr login --name <login_server>   # logga in mot registry (kräver az login sedan innan)

docker compose build     # bygg images lokalt
docker images             # bekräfta att de nya images finns
docker compose push       # pusha upp till Azure Container Registry
```

## 7. Azure Container App – backend

I Azure Portal:
1. Skapa en Container App i rätt resource group
2. Peka på imagen i ditt Container Registry
3. Aktivera **Ingress** (tillåter in/utgående trafik/requests)
4. Testa via **Application URL** (lägg ev. till `/docs` för FastAPI:s auto-genererade dokumentation)

## 8. Azure App Service – frontend

I Azure Portal:
1. Skapa en **Web App** (välj **Container**, inte databas)
2. Under **Environment variables**, lägg till:
   - `WEBSITES_PORT` = `8501` (porten Streamlit körs på)
   - `BACKEND_URL` = `<Application URL från backend Container App>`
3. Starta om appen (refresh)
4. Öppna **Default domain** → ska visa Streamlit-dashboarden

---

# Terraform: deploya container-infrastrukturen automatiskt

Istället för att skapa ACR, Container App och Web App manuellt i portalen (steg 6–8 ovan), automatiseras hela flödet med Terraform + ett deploy-skript.

## 1. Mappstruktur (`infra/`)

**`providers.tf`** – vilken provider (Azure) och vilka versioner som krävs:
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.4"
    }
  }
  required_version = ">= 1.13"
}

provider "azurerm" {
  features {}
}
```

**`random.tf`** – genererar ett slumpmässigt suffix för att undvika namnkrockar (t.ex. ACR-namn måste vara globalt unikt):
```hcl
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
```

**`resource_group.tf`** – resursgruppen allt annat placeras i:
```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
```
> ⚠️ Rättat: variabelreferenser ska **inte** stå inom citattecken (`var.resource-group-name` som text är fel – det ska vara `var.resource_group_name` utan citattecken, annars blir det bokstavligen strängen "var.location" som namn, inte värdet). Bindestreck i variabelnamn (`resource-group-name`) fungerar men är ovanligt i Terraform – använd gärna understreck (`resource_group_name`) för konsekvens.

**`acr.tf`** – Azure Container Registry, dit dina Docker-images pushas:
```hcl
resource "azurerm_container_registry" "acr" {
  name                 = "${var.acr_name}${random_string.suffix.result}"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  sku                  = "Basic"
  admin_enabled        = true
}
```

**`api.tf`** – Container App environment + själva backend-appen:
```hcl
resource "azurerm_container_app_environment" "env" {
  name                = "${var.project_name}-cae"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_container_app" "api" {
  name                          = "${var.project_name}-api"
  resource_group_name           = azurerm_resource_group.rg.name
  container_app_environment_id  = azurerm_container_app_environment.env.id
  revision_mode                 = "Single"

  template {
    container {
      name   = "api"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"   # platshållar-image, byts senare ut mot din egen
      cpu    = 1.0
      memory = "2Gi"
    }
  }

  ingress {
    target_port       = 8000
    external_enabled   = true
    traffic_weight {
      percentage       = 100
      latest_revision  = true
    }
  }
}
```
`ingress` styr om appen ska nås utifrån (`external_enabled = true`) och på vilken port containern lyssnar (`target_port`).

**`web_app.tf`** – App Service för frontend, kopplad till samma ACR:
```hcl
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
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    application_stack {
      docker_image_name   = "frontend:${var.image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
    container_registry_use_managed_identity = true   # ingen lösenordsinloggning behövs
  }

  identity {
    type = "SystemAssigned"   # Azure sköter autentiseringen mot ACR automatiskt
  }

  app_settings = {
    "WEBSITE_PORT"      = "8501"
    "DOCKER_ENABLE_CI"  = "true"
  }
}
```
> ⚠️ Rättat: `name` innehöll tecknet `£` istället för `$` (`£{var.project_name}...`) – ett vanligt tangentbordsmisstag. Ska vara `${var.project_name}-webapp-...` med dollartecken, annars tolkas det inte som en variabel-interpolation.

**`input-variables.tf`** – alla variabler som används ovan, med defaultvärden.

**`outputs.tf`** – värden Terraform skriver ut efter `apply`, t.ex. ACR:ns login-server och namn, så att deploy-skriptet kan läsa dem programmatiskt.

## 2. Registrera Container Apps-providern (första gången, per prenumeration)

```bash
az provider register --namespace Microsoft.App
az provider show --namespace Microsoft.App --query "registrationState"
```
Kontrollerar att Azure-prenumerationen har stöd för Container Apps aktiverat. Ska visa `"Registered"`.

## 3. `deploy_infra.sh` – automatiserar hela flödet

```bash
#!/usr/bin/env bash
set -euo pipefail   # avbryter skriptet direkt vid första fel

IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"   # unik tagg baserad på tidsstämpel, om inget annat anges

TF_DIR="./infra"
cd "$TF_DIR"

echo "[1] Terraform init"
terraform init -input=false -lock=false

echo "[2] Deploy infrastructure"
terraform apply -auto-approve -var="image_tag=$IMAGE_TAG" -lock=false

ACR_LOGIN_SERVER="$(terraform output -raw acr_login_server)"
ACR_NAME="$(terraform output -raw acr_name)"

echo "[3] Login to ACR"
az acr login --name "$ACR_NAME"   # lösenordsfri inloggning, via din befintliga az-session

export IMAGE_TAG
export ACR_LOGIN_SERVER

cd ..

echo "[4] Build and push images"
docker compose build
docker compose push
```

**Vad skriptet gör, steg för steg:**
1. Sätter en unik image-tagg (tidsstämpel) om ingen redan är satt
2. Kör `terraform init` + `apply` för att bygga hela Azure-infrastrukturen
3. Läser ut ACR:ns namn/URL från Terraforms output och loggar in mot registret
4. Exporterar värdena som miljövariabler så `docker-compose.yaml` kan använda dem
5. Bygger och pushar Docker-images till ACR

## 4. Koppla `docker-compose.yaml` till Terraform-outputen

```yaml
services:
  backend:
    image: ${ACR_LOGIN_SERVER}/backend:${IMAGE_TAG:-latest}
  frontend:
    image: ${ACR_LOGIN_SERVER}/frontend:${IMAGE_TAG:-latest}
```

`${ACR_LOGIN_SERVER}` och `${IMAGE_TAG}` hämtas automatiskt från miljövariablerna som `deploy_infra.sh` exporterade i steg 3 ovan.

## 5. Kör skriptet

```bash
chmod +x deploy_infra.sh   # gör filen körbar (krävs en gång, annars nekas körning)
./deploy_infra.sh
```

## 6. Riv ner infrastrukturen

```bash
terraform destroy -auto-approve
```
Körs inifrån `infra/`-mappen. Tar bort allt Terraform skapade (ACR, Container App, Web App, resursgrupp osv).



