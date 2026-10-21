"""Benchmark: FastAPI (uvicorn) kontra Flask (gunicorn).

Dla każdego backendu: startuje serwer, zasypuje go zapytaniami (asyncio + aiohttp, kilka procesów klienta)
przy rosnącej liczbie równoległych połączeń i mierzy przepustowość, opóźnienia oraz zużycie procesora i pamięci
przez procesy serwera. Zapisuje wyniki.json i wykresy wykres_<scenariusz>.png, z których składa się benchmark_backendow.typ.

Uruchomienie:  python3 benchmark.py  (BENCHMARK_CZAS=1 skraca pomiar jednego punktu z 5 s do 1 s), potem  typst compile benchmark_backendow.typ.
Samo kompilowanie dokumentu niczego nie mierzy: składa PDF z zapisanych wyniki.json i wykresów.
"""
import asyncio
import json
import os
import platform
import subprocess
import sys
import threading
import time
import urllib.request
from concurrent.futures import ProcessPoolExecutor
from datetime import datetime
from importlib.metadata import version
from importlib.util import find_spec
from pathlib import Path

import aiohttp
import matplotlib

matplotlib.use("Agg")  # bez okna: rysujemy wyłącznie do plików
import matplotlib.pyplot as plt
import numpy as np
import psutil
from matplotlib.ticker import FuncFormatter, LogLocator, NullFormatter

KATALOG = Path(__file__).resolve().parent
CZAS_POMIARU = float(os.environ.get("BENCHMARK_CZAS", 5))     # sekundy na jeden punkt pomiarowy
ROZGRZEWKA = 1.0                                              # sekundy rozgrzewki przed każdą serią (scenariusz x backend)
WSPOLBIEZNOSC = [1, 10, 50, 200]                              # liczby równoległych połączeń
PROCESY_KLIENTA = max(1, min(4, (os.cpu_count() or 2) // 2))  # generator obciążenia też musi mieć moc, żeby nie być wąskim gardłem
WATKI_FLASK = 16
CZEKAJ_MS = 50                                                # czas oczekiwania w scenariuszu /czekaj (taki sam w obu backendach)

KOLORY = {"FastAPI": "#0f766e", "Flask": "#d97706"}

BACKENDY = {
    "FastAPI": (18101, [sys.executable, "-m", "uvicorn", "backend_fastapi:app", "--host", "127.0.0.1", "--port", "18101",
                        "--log-level", "warning", "--no-access-log"]),
    "Flask": (18102, [sys.executable, "-m", "gunicorn", "backend_flask:app", "-b", "127.0.0.1:18102", "-w", "1",
                      "-k", "gthread", "--threads", str(WATKI_FLASK), "--log-level", "warning"]),
}

LICZBY = json.dumps({"liczby": [i * 0.5 for i in range(100)]}).encode()
SCENARIUSZE = [
    # (id, nazwa, metoda, ścieżka, treść żądania)
    ("ping", "GET /ping", "GET", "/ping", None),
    ("suma", "POST /suma (100 liczb, walidacja)", "POST", "/suma", LICZBY),
    ("czekaj", f"GET /czekaj ({CZEKAJ_MS} ms oczekiwania)", "GET", "/czekaj", None),
]


# ---------- generator obciążenia (działa w osobnych procesach) ----------

async def _petla(sesja, url, metoda, tresc, koniec, opoznienia, bledy):
    naglowki = {"Content-Type": "application/json"} if tresc else None
    while time.perf_counter() < koniec:
        t0 = time.perf_counter()
        try:
            async with sesja.request(metoda, url, data=tresc, headers=naglowki) as odpowiedz:
                await odpowiedz.read()
                poprawna = odpowiedz.status == 200
        except Exception:
            poprawna = False
        if poprawna:
            opoznienia.append(time.perf_counter() - t0)
        else:
            bledy[0] += 1


async def _klient_async(url, metoda, tresc, polaczenia, czas):
    opoznienia, bledy = [], [0]
    polaczenie = aiohttp.TCPConnector(limit=polaczenia)
    async with aiohttp.ClientSession(connector=polaczenie, timeout=aiohttp.ClientTimeout(total=30)) as sesja:
        start = time.perf_counter()
        await asyncio.gather(*[_petla(sesja, url, metoda, tresc, start + czas, opoznienia, bledy) for _ in range(polaczenia)])
        trwanie = time.perf_counter() - start
    return np.array(opoznienia), bledy[0], trwanie


def klient(url, metoda, tresc, polaczenia, czas):
    return asyncio.run(_klient_async(url, metoda, tresc, polaczenia, czas))


# ---------- pomiar zużycia zasobów przez serwer ----------

def _drzewo(pid):
    glowny = psutil.Process(pid)
    return [glowny] + glowny.children(recursive=True)


def _czas_cpu(procesy):
    suma = 0.0
    for p in procesy:
        try:
            t = p.cpu_times()
            suma += t.user + t.system
        except psutil.NoSuchProcess:
            pass
    return suma


def _pamiec_mb(procesy):
    suma = 0
    for p in procesy:
        try:
            try:
                suma += p.memory_full_info().pss          # PSS dzieli pamięć wspólną między procesy, więc sumuje się poprawnie
            except (psutil.AccessDenied, AttributeError):
                suma += p.memory_info().rss
        except psutil.NoSuchProcess:
            pass
    return suma / 1024 ** 2


def zmierz(pula, port, scenariusz, polaczenia, czas, pid_serwera):
    _, _, metoda, sciezka, tresc = scenariusz
    url = f"http://127.0.0.1:{port}{sciezka}"
    n = min(PROCESY_KLIENTA, polaczenia)
    udzialy = [polaczenia // n + (1 if i < polaczenia % n else 0) for i in range(n)]

    procesy = _drzewo(pid_serwera)
    probki_pamieci, stop = [], threading.Event()

    def probkuj():
        while not stop.is_set():
            probki_pamieci.append(_pamiec_mb(procesy))
            stop.wait(0.2)

    watek = threading.Thread(target=probkuj)
    cpu0, t0 = _czas_cpu(procesy), time.perf_counter()
    watek.start()
    wyniki = [f.result() for f in [pula.submit(klient, url, metoda, tresc, u, czas) for u in udzialy]]
    stop.set()
    watek.join()
    trwanie_okna, cpu1 = time.perf_counter() - t0, _czas_cpu(procesy)

    opoznienia = np.concatenate([w[0] for w in wyniki]) * 1000        # ms
    bledy = sum(w[1] for w in wyniki)
    zapytania = len(opoznienia)
    trwanie = max(w[2] for w in wyniki)
    procentyle = np.percentile(opoznienia, [50, 95, 99]) if zapytania else [None] * 3
    return {
        "zapytania": zapytania,
        "bledy": bledy,
        "rps": zapytania / trwanie,
        "p50_ms": None if procentyle[0] is None else float(procentyle[0]),
        "p95_ms": None if procentyle[1] is None else float(procentyle[1]),
        "p99_ms": None if procentyle[2] is None else float(procentyle[2]),
        "cpu_proc": (cpu1 - cpu0) / trwanie_okna * 100,                # 100 % = pełne obciążenie jednego rdzenia
        "cpu_ms_na_zapytanie": (cpu1 - cpu0) / zapytania * 1000 if zapytania else None,
        "pamiec_mb": max(probki_pamieci) if probki_pamieci else None,
    }


# ---------- obsługa serwerów ----------

def uruchom_serwer(polecenie, port):
    serwer = subprocess.Popen(polecenie, cwd=KATALOG, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(200):
        if serwer.poll() is not None:
            raise RuntimeError(f"serwer zakończył pracę zaraz po starcie (kod {serwer.returncode}): {' '.join(polecenie)}")
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/ping", timeout=1) as odpowiedz:
                if odpowiedz.status == 200:
                    return serwer
        except OSError:
            time.sleep(0.1)
    serwer.kill()
    raise RuntimeError(f"serwer nie wystartował na porcie {port}")


def zatrzymaj_serwer(serwer):
    procesy = _drzewo(serwer.pid)
    serwer.terminate()
    try:
        serwer.wait(timeout=10)
    except subprocess.TimeoutExpired:
        for p in procesy:
            p.kill()


# ---------- opis maszyny i konfiguracji ----------

def model_procesora():
    try:
        for linia in Path("/proc/cpuinfo").read_text().splitlines():
            if linia.startswith("model name"):
                return linia.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or "nieznany"


def opis_maszyny():
    return {
        "data": datetime.now().strftime("%d.%m.%Y %H:%M"),
        "procesor": model_procesora(),
        "rdzenie_fizyczne": psutil.cpu_count(logical=False),
        "rdzenie_logiczne": psutil.cpu_count(logical=True),
        "pamiec_gb": round(psutil.virtual_memory().total / 1024 ** 3, 1),
        "system": platform.platform(),
        "python": platform.python_version(),
        "wersje": {nazwa: version(nazwa) for nazwa in ("fastapi", "pydantic", "uvicorn", "flask", "werkzeug", "gunicorn", "aiohttp")},
    }


def opis_konfiguracji():
    petla = "uvloop" if find_spec("uvloop") else "asyncio"
    parser = "httptools" if find_spec("httptools") else "h11"
    return {
        "czas_pomiaru_s": CZAS_POMIARU,
        "rozgrzewka_s": ROZGRZEWKA,
        "wspolbieznosc": WSPOLBIEZNOSC,
        "procesy_klienta": PROCESY_KLIENTA,
        "watki_flask": WATKI_FLASK,
        "czekaj_ms": CZEKAJ_MS,
        "serwery": {
            "FastAPI": f"uvicorn {version('uvicorn')} (pętla: {petla}, parser HTTP: {parser}), 1 proces, endpointy async",
            "Flask": f"gunicorn {version('gunicorn')}, klasa gthread, 1 proces, {WATKI_FLASK} wątków, endpointy synchroniczne",
        },
        "scenariusze": [{"id": s[0], "nazwa": s[1]} for s in SCENARIUSZE],
    }


# ---------- wykresy ----------

PANELE = [  # (klucz w wynikach, tytuł, oś Y, skala logarytmiczna)
    ("rps", "Przepustowość", "zapytań na sekundę", False),
    ("p95_ms", "Opóźnienie (95. percentyl)", "ms (skala logarytmiczna)", True),
    ("cpu_proc", "Procesor zajmowany przez serwer", "% jednego rdzenia", False),
    ("pamiec_mb", "Pamięć zajmowana przez serwer (PSS)", "MB", False),
]


def ustaw_zakres_y(ax, wartosci, log):
    """Zapas nad i pod krzywymi, żeby żaden punkt nie leżał na ramce wykresu."""
    if not wartosci:
        return
    dol, gora = min(wartosci), max(wartosci)
    if log:
        ax.set_ylim(dol / 1.7, gora * 1.7)
        return
    ax.set_ylim(-0.08 * gora, gora * 1.15)
    ax.set_yticks([t for t in ax.get_yticks() if 0 <= t <= gora * 1.15])  # bez ujemnych wartości na osi
    ax.set_ylim(-0.08 * gora, gora * 1.15)


def rysuj_scenariusz(wyniki, scenariusz):
    id_, nazwa = scenariusz[0], scenariusz[1]
    plt.rcParams.update({"font.size": 11, "axes.titlesize": 12, "axes.labelsize": 11})
    figure, osie = plt.subplots(2, 2, figsize=(9, 6.6))
    for ax, (klucz, tytul, etykieta_y, log_y) in zip(osie.flat, PANELE):
        wartosci = []
        for backend in BACKENDY:
            punkty = [w for w in wyniki if w["backend"] == backend and w["scenariusz"] == id_ and w[klucz] is not None]
            ax.plot([w["wspolbieznosc"] for w in punkty], [w[klucz] for w in punkty], "o-",
                    color=KOLORY[backend], linewidth=2.2, markersize=7, label=backend)
            wartosci += [w[klucz] for w in punkty]
        ax.set_xscale("log")
        ax.set_xticks(WSPOLBIEZNOSC, [str(c) for c in WSPOLBIEZNOSC])
        ax.minorticks_off()
        ax.set_xlim(WSPOLBIEZNOSC[0] / 1.5, WSPOLBIEZNOSC[-1] * 1.5)
        if log_y:
            ax.set_yscale("log")
            ax.yaxis.set_major_locator(LogLocator(subs=(1, 2, 5)))              # etykiety 1, 2, 5, 10, 20, 50, ...
            ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: f"{v:g}"))  # zwykłe liczby zamiast 10^n
            ax.yaxis.set_minor_formatter(NullFormatter())
        ustaw_zakres_y(ax, wartosci, log_y)
        ax.set_title(tytul)
        ax.set_xlabel("równoległe połączenia")
        ax.set_ylabel(etykieta_y)
        ax.grid(alpha=0.3)
    uchwyty, napisy = osie[0, 0].get_legend_handles_labels()
    figure.legend(uchwyty, napisy, loc="upper center", ncol=2, frameon=False, fontsize=12)
    figure.tight_layout(rect=(0, 0, 1, 0.96))
    figure.savefig(KATALOG / f"wykres_{id_}.png", dpi=170)
    plt.close(figure)


def main():
    wyniki = []
    with ProcessPoolExecutor(max_workers=PROCESY_KLIENTA) as pula:
        for backend, (port, polecenie) in BACKENDY.items():
            print(f"[benchmark] {backend}: start serwera", flush=True)
            serwer = uruchom_serwer(polecenie, port)
            try:
                for scenariusz in SCENARIUSZE:
                    zmierz(pula, port, scenariusz, 10, ROZGRZEWKA, serwer.pid)                 # rozgrzewka (wynik odrzucamy)
                    for polaczenia in WSPOLBIEZNOSC:
                        w = zmierz(pula, port, scenariusz, polaczenia, CZAS_POMIARU, serwer.pid)
                        w.update(backend=backend, scenariusz=scenariusz[0], wspolbieznosc=polaczenia)
                        wyniki.append(w)
                        print(f"[benchmark] {backend:8} {scenariusz[1]:36} {polaczenia:>4} pol.: {w['rps']:8.0f} rps, "
                              f"p95 {w['p95_ms'] or 0:7.1f} ms, CPU {w['cpu_proc']:5.0f} %, błędy {w['bledy']}", flush=True)
            finally:
                zatrzymaj_serwer(serwer)

    (KATALOG / "wyniki.json").write_text(json.dumps(
        {"maszyna": opis_maszyny(), "konfiguracja": opis_konfiguracji(), "wyniki": wyniki}, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8")
    for scenariusz in SCENARIUSZE:
        rysuj_scenariusz(wyniki, scenariusz)
    print("[benchmark] zapisano wyniki.json i wykresy", flush=True)


if __name__ == "__main__":
    main()
