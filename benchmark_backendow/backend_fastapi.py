"""Backend do benchmarku: FastAPI. Te same trzy endpointy co w backend_flask.py.

Uruchomienie ręczne:  python3 -m uvicorn backend_fastapi:app --port 18101
"""
import asyncio

from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()


class Liczby(BaseModel):
    liczby: list[float]            # pydantic sprawdza typy, zanim wywoła się funkcja


@app.get("/ping")
async def ping():
    return {"status": "ok"}


@app.post("/suma")
async def suma(dane: Liczby):
    return {"suma": sum(dane.liczby), "ile": len(dane.liczby)}


@app.get("/czekaj")
async def czekaj():
    await asyncio.sleep(0.05)      # udaje czekanie na bazę danych lub inną usługę; pętla zdarzeń obsługuje w tym czasie inne żądania
    return {"status": "ok"}
