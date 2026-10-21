"""Backend do benchmarku: Flask. Te same trzy endpointy co w backend_fastapi.py.

Uruchomienie ręczne:  python3 -m gunicorn backend_flask:app -b 127.0.0.1:18102 -k gthread --threads 16
"""
import time

from flask import Flask, jsonify, request

app = Flask(__name__)


@app.get("/ping")
def ping():
    return jsonify(status="ok")


@app.post("/suma")
def suma():
    dane = request.get_json(silent=True)
    liczby = dane.get("liczby") if isinstance(dane, dict) else None
    # Flask nie waliduje danych sam, więc robimy to ręcznie (to samo sprawdza pydantic we FastAPI)
    if not isinstance(liczby, list) or not all(isinstance(x, (int, float)) and not isinstance(x, bool) for x in liczby):
        return jsonify(blad="oczekiwano {\"liczby\": [liczba, ...]}"), 422
    return jsonify(suma=sum(liczby), ile=len(liczby))


@app.get("/czekaj")
def czekaj():
    time.sleep(0.05)               # udaje czekanie na bazę danych lub inną usługę; blokuje wątek, który obsługuje to żądanie
    return jsonify(status="ok")
