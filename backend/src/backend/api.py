from fastapi import FastAPI
from backend.data_processing import df, number_per_type, filtered_types

app = FastAPI()


@app.get("/pokemons/stats")
async def show_data():
    return df.to_dict(orient="records")


@app.get("/pokemons/number_types")
async def number_pokemons_per_type():
    return number_per_type.to_dict()


@app.get("/pokemons/type")
async def filter_pokemon_type(poke_type):
    return filtered_types(poke_type).to_dict(orient="records")