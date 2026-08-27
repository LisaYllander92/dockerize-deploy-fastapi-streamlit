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