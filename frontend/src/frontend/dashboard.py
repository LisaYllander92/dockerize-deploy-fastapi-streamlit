import streamlit as st
import httpx 
import os

# os.getenv försöker hämtar miljövariabel BACKEND_URL, om den inte finns - default andra variabeln (http...)
BASE_URL = os.getenv("BACKEND_URL", "http://127.0.0.1:8000")

def main():
    st.markdown("# PokeDash")

    st.write(BASE_URL)

    stats = httpx.get(f"{BASE_URL}/pokemon/stats", timeout=30).json()
    st.dataframe(stats)

if __name__ == "__main__":
    main()
