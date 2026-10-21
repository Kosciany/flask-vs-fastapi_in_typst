# flask-vs-fastapi_in_typst

> To repozytorium służy wyłącznie jako **przykład dla studentów**: jak napisać raport w Typst i jak użyć Pythona do wygenerowania wykresów, które trafiają do tego raportu.

Dwa niezależne przykłady. W obu Python przygotowuje dane i obrazy, a Typst składa z nich gotowy PDF.

| Katalog | Co pokazuje | Wynik |
|---|---|---|
| [`typst_w_pigulce/`](typst_w_pigulce/) | składnia Typsta, matematyka, wczytywanie kodu z pliku, wykres z matplotliba, wiele stylów z jednego źródła | [`typst_w_pigulce_artykul.pdf`](typst_w_pigulce/typst_w_pigulce_artykul.pdf), [`typst_w_pigulce_latex.pdf`](typst_w_pigulce/typst_w_pigulce_latex.pdf) |
| [`benchmark_backendow/`](benchmark_backendow/) | pełny raport: skrypt mierzy dwa serwery (FastAPI i Flask), zapisuje `wyniki.json` i wykresy, a Typst z tych danych sam wylicza liczby w tekście | [`benchmark_backendow.pdf`](benchmark_backendow/benchmark_backendow.pdf) |

Gotowe PDF-y leżą w repozytorium, więc można je obejrzeć bez instalowania czegokolwiek.

## Idea

```
skrypt Pythona  ──►  wykres.png / wyniki.json  ──►  dokument .typ  ──►  PDF
(matplotlib, pomiary)                              (typst compile)
```

Dokument `.typ` nie zawiera przepisanych liczb. Wczytuje je z pliku (`json("wyniki.json")`) i obrazy z pliku (`image("wykres_ping.png")`), więc po ponownym pomiarze wystarczy skompilować dokument jeszcze raz.

## Wymagania

- [Typst](https://typst.app/) 0.13 lub nowszy (sprawdzone na 0.15)
- Python 3.10+ i `pip install -r requirements.txt`
- czcionki Liberation Sans i JetBrains Mono (używa ich styl „artykuł”; styl „LaTeX” korzysta z czcionek wbudowanych w Typst)
- do pomiarów (tylko `benchmark.py`): Linux lub macOS, bo skrypt odczytuje zużycie zasobów procesów serwera

## Użycie

Typst w pigułce:

```bash
cd typst_w_pigulce
python3 generuj_wykres.py                                                       # tworzy wykres.png
typst compile --input styl=artykul typst_w_pigulce.typ typst_w_pigulce_artykul.pdf
typst compile --input styl=latex   typst_w_pigulce.typ typst_w_pigulce_latex.pdf
```

Benchmark backendów:

```bash
cd benchmark_backendow
typst compile benchmark_backendow.typ                  # sam PDF z zapisanych wyników
python3 benchmark.py && typst compile benchmark_backendow.typ   # pomiar od nowa (ok. 2 minuty), potem PDF
BENCHMARK_CZAS=1 python3 benchmark.py                  # skrócony pomiar na próbę
```

Liczby w raporcie zależą od maszyny, na której zrobiono pomiar. Opis sprzętu i wersji bibliotek jest w raporcie.
