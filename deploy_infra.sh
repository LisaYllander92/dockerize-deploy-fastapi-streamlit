#!/usr/bin/env bash
set -euo pipefail # bash strict mode -> crashes immediately at error

IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"

TF_DIR="./infra"

cd "$TF_DIR"

echo "[1] Terraform init"
terraform init -input=false -lock=false

echo "[2] Deploy infrastructure"
terraform apply -auto-approve -var=image_tag="$IMAGE_TAG" -lock=false

ACR_LOGIN_SERVER="$(terraform output -raw acr_login_server)"
ACR_NAME="$(terraform output -raw acr_name)"

echo "[3] Login to ACR"
az acr login --name "$ACR_NAME" # passwordless login

# pushes variables to environment memory so docker can use it
export IMAGE_TAG
export ACR_LOGIN_SERVER

cd ..

echo "[4] Build and push images"
docker compose build
docker compose push