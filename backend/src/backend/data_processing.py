import pandas as pd
from backend.constants import DATA_PATH


df = pd.read_csv(DATA_PATH / "Pokemon.csv")
df["Type 2"] = df["Type 2"].fillna("missing")


number_per_type = (
    pd.concat([df["Type 1"].value_counts(), df["Type 2"].value_counts()])
    .groupby(level=0)
    .sum()
    .sort_values(ascending=False)
    .drop("missing")
)


def filtered_types(poke_type):
    poke_type = poke_type.capitalize().strip()
    return df.query("`Type 1` == @poke_type or `Type 2` == @poke_type")