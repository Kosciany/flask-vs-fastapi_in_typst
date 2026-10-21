// Benchmark FastAPI i Flask. Dane (wyniki.json) i wykresy (wykres_<scenariusz>.png) powstają w benchmark.py, uruchamianym osobno
// (python3 benchmark.py, ok. 2 minuty). Samo składanie PDF-a (typst compile benchmark_backendow.typ) niczego nie mierzy.
// Opisy teoretyczne (co robi endpoint, jak działa serwer) są stałe, a zdania z liczbami wylicza Typst z wyniki.json.
#import "szablon_artykul.typ": szablon-artykul

#let d = json("wyniki.json")
#let m = d.maszyna
#let k = d.konfiguracja

#show: szablon-artykul.with(
  title: "Benchmark: FastAPI i Flask",
  subtitle: "porównanie dwóch backendów pod obciążeniem",
  date: m.data,
)

#let backendy = ("FastAPI", "Flask")
#let cmin = k.wspolbieznosc.first()
#let cmax = k.wspolbieznosc.last()

// ---------- pomocnicze: formatowanie i dostęp do wyników ----------
#let fmt(x, cyfry: 0) = if x == none { "–" } else {
  let t = str(calc.round(float(x), digits: cyfry))
  if cyfry == 0 { t = t.split(".").first() }
  t.replace(".", ",")
}
#let wiersze(b, sc) = d.wyniki.filter(w => w.backend == b and w.scenariusz == sc)
#let punkt(b, sc, c) = d.wyniki.find(w => w.backend == b and w.scenariusz == sc and w.wspolbieznosc == c)
#let najlepszy(b, sc) = wiersze(b, sc).sorted(key: w => -w.rps).first()
#let rozstep(b, sc, klucz) = {
  let v = wiersze(b, sc).map(w => w.at(klucz)).filter(x => x != none)
  calc.max(..v) - calc.min(..v)
}
// kto jest lepszy i ile razy (większa wartość = lepiej / mniejsza wartość = lepiej)
#let razy-wiecej(fa, fl) = if fa >= fl [FastAPI obsłużył #fmt(fa / fl, cyfry: 1) razy więcej zapytań] else [Flask obsłużył #fmt(fl / fa, cyfry: 1) razy więcej zapytań]
#let razy-szybciej(fa, fl) = if fa <= fl [FastAPI odpowiadał #fmt(fl / fa, cyfry: 1) razy szybciej] else [Flask odpowiadał #fmt(fa / fl, cyfry: 1) razy szybciej]

= Cel i metoda

Porównujemy dwa popularne frameworki webowe Pythona, wystawiając w każdym te same trzy endpointy. *FastAPI* jest frameworkiem
asynchronicznym (standard ASGI) i działa pod serwerem `uvicorn`. *Flask* jest frameworkiem synchronicznym (standard WSGI) i działa pod
serwerem `gunicorn`. Wynik zależy od maszyny, na której liczymy, dlatego zestawienie można wygenerować od nowa (benchmark.py),
razem z opisem sprzętu i wersji bibliotek.

*Przebieg pomiaru.* Dla każdego backendu: (1) startujemy serwer, (2) rozgrzewamy go krótkim ruchem, (3) generator obciążenia otwiera
zadaną liczbę równoległych połączeń. Każde połączenie w pętli wysyła żądanie, czeka na odpowiedź i od razu wysyła następne, i tak przez
#fmt(k.czas_pomiaru_s, cyfry: 0) s. W tym czasie próbkujemy zasoby procesów serwera. Całość powtarzamy dla liczby połączeń równej
#k.wspolbieznosc.map(str).join(", "). Backendy mierzymy kolejno, nie jednocześnie, żeby nie konkurowały o procesor.

*Co oznaczają metryki.*
- *RPS* (zapytania na sekundę): ile zapytań serwer obsłużył w ciągu sekundy. Im więcej, tym lepiej.
- *p95 \[ms\]*: opóźnienie, w którym mieści się 95% odpowiedzi (jedna na dwadzieścia jest wolniejsza). Mówi o tym, co widzi użytkownik, lepiej niż średnia. Im mniej, tym lepiej.
- *CPU \[%\]*: czas procesora zużyty przez procesy serwera podzielony przez czas pomiaru. 100% oznacza pełne obciążenie jednego rdzenia. Wartość może lekko przekroczyć 100%, bo część pracy (np. obsługa sieci w jądrze systemu) wykonuje się poza interpreterem Pythona i może biec równolegle.
- *CPU \[ms/zap.\]*: ile czasu procesora kosztuje jedno zapytanie. Pokazuje efektywność, niezależnie od tego, ile zapytań przyszło.
- *RAM \[MB\]*: pamięć zajmowana przez procesy serwera (miara PSS, która poprawnie dzieli pamięć współdzieloną między procesy).

*Dlaczego opóźnienia rosną razem z liczbą połączeń.* Gdy serwer jest nasycony, czyli nie nadąża z obsługą, nowe żądania czekają w kolejce.
Zgodnie z prawem Little'a liczba żądań w systemie jest równa przepustowości razy czas odpowiedzi, czyli
$ "czas odpowiedzi" approx "liczba połączeń" / "przepustowość" . $
Jeśli przepustowość jest stała (serwer wykorzystał już cały dostępny procesor), to dziesięć razy więcej połączeń daje około dziesięć razy
dłuższy czas odpowiedzi. Dlatego na wykresach przepustowość „wypłaszcza się”, a opóźnienie rośnie prawie liniowo.

*Jak czytać wykresy.* Każdy scenariusz ma jeden wykres z czterema panelami: przepustowość (wyżej znaczy lepiej), opóźnienie p95 (niżej znaczy
lepiej; oś jest logarytmiczna, więc równe odstępy oznaczają stałe krotności), procesor i pamięć. Oś pozioma pokazuje liczbę równoległych
połączeń, również w skali logarytmicznej.

*Ograniczenia.* Generator obciążenia i serwer działają na tej samej maszynie i dzielą procesor. Każdy serwer ma jeden proces. Wynik to
pojedynczy przebieg, więc drobne różnice (kilka procent) mieszczą się w szumie pomiarowym.

= Konfiguracja pomiaru

#table(
  columns: (auto, 1fr),
  align: (left, left),
  stroke: none,
  fill: (_, y) => if calc.odd(y) { rgb("#f8f9fa") },
  [*Procesor*], [#m.procesor],
  [*Rdzenie*], [#m.rdzenie_fizyczne fizycznych, #m.rdzenie_logiczne logicznych],
  [*Pamięć RAM*], [#fmt(m.pamiec_gb, cyfry: 1) GB],
  [*System*], [#m.system],
  [*Python*], [#m.python],
  [*FastAPI*], [#k.serwery.FastAPI],
  [*Flask*], [#k.serwery.Flask],
  [*Biblioteki*], [fastapi #m.wersje.fastapi, pydantic #m.wersje.pydantic, flask #m.wersje.flask, werkzeug #m.wersje.werkzeug, aiohttp #m.wersje.aiohttp],
  [*Generator obciążenia*], [aiohttp, #k.procesy_klienta procesów klienta; serwer i klient na tej samej maszynie, backendy mierzone kolejno],
  [*Pomiar punktu*], [#fmt(k.czas_pomiaru_s, cyfry: 1) s po #fmt(k.rozgrzewka_s, cyfry: 1) s rozgrzewki; równoległe połączenia: #k.wspolbieznosc.map(str).join(", ")],
  [*Błędy (łącznie)*], [#backendy.map(b => b + ": " + str(d.wyniki.filter(w => w.backend == b).map(w => w.bledy).sum())).join("; ")],
)

= Scenariusze

// ---------- zdania z liczbami, wyliczane z wyników ----------
#let pomiary(sc) = {
  let (fa, fl) = (najlepszy("FastAPI", sc), najlepszy("Flask", sc))
  let (ka, kl) = (punkt("FastAPI", sc, cmax), punkt("Flask", sc, cmax))
  [
    *Co pokazały pomiary.* Największą przepustowość FastAPI osiągnął przy #fa.wspolbieznosc połączeniach: #fmt(fa.rps) zapytań/s.
    Flask osiągnął #fmt(fl.rps) zapytań/s przy #fl.wspolbieznosc połączeniach, więc #razy-wiecej(fa.rps, fl.rps).
    Przy #cmax połączeniach 95% odpowiedzi FastAPI mieściło się w #fmt(ka.p95_ms, cyfry: 1) ms, a Flaska w #fmt(kl.p95_ms, cyfry: 1) ms
    (#razy-szybciej(ka.p95_ms, kl.p95_ms)). W tym czasie serwery zajmowały #fmt(ka.cpu_proc)% i #fmt(kl.cpu_proc)% jednego rdzenia,
    a jedno zapytanie kosztowało średnio #fmt(ka.cpu_ms_na_zapytanie, cyfry: 2) ms procesora w FastAPI i
    #fmt(kl.cpu_ms_na_zapytanie, cyfry: 2) ms we Flasku. Pamięć serwerów zmieniła się w trakcie całego scenariusza najwyżej o #fmt(calc.max(rozstep("FastAPI", sc, "pamiec_mb"), rozstep("Flask", sc, "pamiec_mb")), cyfry: 1) MB.
  ]
}

#let tabela(sc) = {
  set text(size: 9pt)
  table(
    columns: (auto,) + (1fr,) * 10,
    align: center + horizon,
    inset: 5pt,
    table.header(
      table.cell(rowspan: 2)[*Połącz.*],
      table.cell(colspan: 5)[*FastAPI*], table.cell(colspan: 5)[*Flask*],
      ..for _ in backendy { ([RPS], [p95 \[ms\]], [CPU \[%\]], [CPU \[ms/zap.\]], [RAM \[MB\]]) },
    ),
    ..for c in k.wspolbieznosc {
      (str(c),)
      for b in backendy {
        let w = punkt(b, sc, c)
        (
          fmt(w.rps), fmt(w.p95_ms, cyfry: 1), fmt(w.cpu_proc),
          fmt(w.cpu_ms_na_zapytanie, cyfry: 2), fmt(w.pamiec_mb, cyfry: 1),
        )
      }
    },
  )
}

#let wykres(sc, nazwa) = figure(
  image("wykres_" + sc + ".png", width: 100%),
  caption: [Wyniki scenariusza #nazwa: przepustowość, opóźnienie, procesor i pamięć w funkcji liczby połączeń.],
)

// ---------- GET /ping ----------
#let nazwa-ping = k.scenariusze.find(s => s.id == "ping").nazwa
== #nazwa-ping

*Co robi endpoint.* Zwraca stały, mały obiekt JSON (`{"status": "ok"}`) i nie wykonuje żadnej pracy po stronie aplikacji. Mierzymy więc wyłącznie
narzut frameworka i serwera: odczyt żądania HTTP, wywołanie funkcji i zapis odpowiedzi.

*Czego się spodziewać.* Praca na jedno zapytanie jest krótka, ale w całości zajmuje procesor. Każdy serwer działa w jednym procesie Pythona, więc
wykorzysta najwyżej jeden rdzeń. Gdy rdzeń jest zajęty w 100%, dokładanie połączeń nie podnosi przepustowości, tylko wydłuża kolejkę. Wygrywa ten
serwer, który na jedno zapytanie zużywa mniej czasu procesora.

#pomiary("ping")

Sprawdzenie prawem Little'a: przy #cmax połączeniach FastAPI miał przepustowość #fmt(punkt("FastAPI", "ping", cmax).rps) zapytań/s, co daje
#fmt(cmax / punkt("FastAPI", "ping", cmax).rps * 1000, cyfry: 1) ms na odpowiedź (zmierzona mediana: #fmt(punkt("FastAPI", "ping", cmax).p50_ms, cyfry: 1) ms).
Dla Flaska wychodzi #fmt(cmax / punkt("Flask", "ping", cmax).rps * 1000, cyfry: 1) ms (mediana: #fmt(punkt("Flask", "ping", cmax).p50_ms, cyfry: 1) ms).

#wykres("ping", nazwa-ping)
#tabela("ping")

// ---------- POST /suma ----------
#let nazwa-suma = k.scenariusze.find(s => s.id == "suma").nazwa
== #nazwa-suma

*Co robi endpoint.* Przyjmuje w treści żądania JSON z listą stu liczb (`{"liczby": [...]}`), sprawdza, czy dane mają poprawny kształt, i zwraca ich sumę
oraz liczbę. Pracy jest więcej niż w `/ping`: serwer musi odczytać treść, zamienić JSON na obiekty Pythona i zwalidować każdy element.

*Czego się spodziewać.* We FastAPI walidację robi `pydantic` (jego rdzeń jest napisany w Rust), a we Flasku robimy ją ręcznie, pętlą w Pythonie. Obie wersje
sprawdzają to samo, ale koszt procesora na zapytanie jest inny. Scenariusz nadal jest ograniczony procesorem, więc obowiązują te same zasady co w
poprzednim: po nasyceniu rdzenia przepustowość stoi, a opóźnienie rośnie wraz z liczbą połączeń.

#pomiary("suma")

W porównaniu ze scenariuszem `/ping` maksymalna przepustowość FastAPI spadła do
#fmt(najlepszy("FastAPI", "suma").rps / najlepszy("FastAPI", "ping").rps * 100)%, a Flaska do
#fmt(najlepszy("Flask", "suma").rps / najlepszy("Flask", "ping").rps * 100)% wartości z `/ping`. Różnica to koszt odczytania i sprawdzenia treści żądania.

#wykres("suma", nazwa-suma)
#tabela("suma")

// ---------- GET /czekaj ----------
#let nazwa-czekaj = k.scenariusze.find(s => s.id == "czekaj").nazwa
#let limit-flask = k.watki_flask / (k.czekaj_ms / 1000)
#let limit-fastapi = cmax / (k.czekaj_ms / 1000)
== #nazwa-czekaj

*Co robi endpoint.* Czeka #k.czekaj_ms ms, po czym zwraca stały JSON. To odpowiednik zapytania do bazy danych albo zewnętrznej usługi: aplikacja
nic nie liczy, tylko czeka na odpowiedź. Procesor prawie nie pracuje, więc ograniczeniem nie jest jego moc, tylko to, *ile żądań serwer potrafi mieć w toku
jednocześnie*.

*Dlaczego frameworki zachowują się tu różnie.* FastAPI jest asynchroniczny: funkcja `async def` z `await asyncio.sleep(...)` na czas czekania oddaje sterowanie
pętli zdarzeń, która w tym czasie obsługuje inne żądania. Jeden proces może więc czekać równolegle na setki zapytań. Flask jest synchroniczny:
`time.sleep(...)` blokuje wątek na cały czas czekania. Skonfigurowany serwer ma #k.watki_flask wątków, więc obsłuży jednocześnie najwyżej tyle żądań, a pozostałe
czekają w kolejce.

*Co mówi teoria.* Przepustowość nie może przekroczyć liczby żądań w toku podzielonej przez czas jednego żądania. Dla Flaska to
#k.watki_flask / #fmt(k.czekaj_ms / 1000, cyfry: 2) s = #fmt(limit-flask) zapytań/s niezależnie od liczby połączeń. Dla FastAPI przy #cmax połączeniach limit to
#cmax / #fmt(k.czekaj_ms / 1000, cyfry: 2) s = #fmt(limit-fastapi) zapytań/s i rośnie wraz z liczbą połączeń.

#pomiary("czekaj")

Zmierzona przepustowość przy #cmax połączeniach to #fmt(punkt("FastAPI", "czekaj", cmax).rps / limit-fastapi * 100)% limitu teoretycznego dla FastAPI i
#fmt(punkt("Flask", "czekaj", cmax).rps / limit-flask * 100)% limitu dla Flaska. Przy #cmin połączeniu każdy serwer ma w toku jedno żądanie naraz, więc
przepustowość wynosi #fmt(punkt("FastAPI", "czekaj", cmin).rps) zapytań/s dla FastAPI i #fmt(punkt("Flask", "czekaj", cmin).rps) dla Flaska, czyli około #fmt(1000 / k.czekaj_ms)
(jedno żądanie na #k.czekaj_ms ms).

#wykres("czekaj", nazwa-czekaj)
#tabela("czekaj")
