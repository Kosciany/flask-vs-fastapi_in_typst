// Typst w pigułce: jeden plik z treścią, wygląd wybierany parametrem.
// Z tego samego pliku powstają dwa dokumenty (własny styl i styl LaTeX-a):
//   typst compile --input styl=artykul typst_w_pigulce.typ typst_w_pigulce_artykul.pdf
//   typst compile --input styl=latex   typst_w_pigulce.typ typst_w_pigulce_latex.pdf
// Wcześniej trzeba uruchomić:  python3 generuj_wykres.py
//
// warianty: artykul latex

// ---------- wybór stylu: parametr --input styl=... (domyślnie artykul) ----------
#import "_styl_artykul.typ" as artykul
#import "_styl_latex.typ" as latex

#let style = (artykul: artykul, latex: latex)
#let wybrany = sys.inputs.at("styl", default: "artykul")
#assert(wybrany in style, message: "nieznany styl: " + wybrany + " (dozwolone: " + style.keys().join(", ") + ")")
#let s = style.at(wybrany)

#show: s.styl.with(
  title: "Typst w pigułce",
  subtitle: "składnia, matematyka, skrypty, kod i wykresy w jednym dokumencie",
)

// ---------- funkcja pomocnicza: pokazuje kod razem z jego wynikiem ----------
#let przyklad(kod, scope: (:), pionowo: false) = block(breakable: false, grid(
  columns: if pionowo { (1fr,) } else { (1fr, 1fr) },
  gutter: 10pt,
  align: horizon,
  raw(kod, lang: "typ", block: true),
  block(fill: s.kolory.tlo, inset: 10pt, radius: 4pt, width: 100%, {
    set math.equation(numbering: none)  // w przykładach wzory bez numerów
    eval(kod, mode: "markup", scope: scope)
  }),
))

= Wstęp

Ten dokument pokazuje możliwości Typsta na własnym przykładzie: powstał z jednego pliku tekstowego
(`typst_w_pigulce.typ`) i jednego skryptu Pythona (`generuj_wykres.py`). Typst jest językiem składu tekstu
podobnym do LaTeX-a, ale kompiluje się w ułamku sekundy, a jego część skryptowa jest prawdziwym językiem
programowania. Ten egzemplarz, w stylu *#s.motyw.nazwa*, ma #context counter(page).final().first() strony,
a liczbę tę wstawił sam Typst.

W kolejnych sekcjach pokazujemy po kolei składnię, matematykę, kod wczytywany z pliku, obraz wygenerowany
przez Pythona oraz obliczenia wykonywane w trakcie składania dokumentu. Na końcu wyjaśniamy, jak z tej
samej treści powstają dokumenty o różnym wyglądzie.

= Składnia

Zwykły tekst piszemy tak, jak jest, a formatowanie zaznaczamy prostymi znakami. W przykładach poniżej
po lewej stoi to, co wpisujemy, a po prawej to, co z tego powstaje. Prawa strona nie jest obrazkiem:
dokument wykonuje kod na żywo.

#przyklad("*pogrubienie*, _kursywa_, `kod`,
#underline[podkreślenie]
i #text(fill: red)[kolorowy tekst].")

Listy numerowane i punktowane zaczynamy od `+` i `-`, a wcięcie tworzy zagnieżdżenie:

#przyklad("+ pierwszy punkt
+ drugi punkt
  - zagnieżdżona lista
+ trzeci punkt")

Odnośniki i przypisy też są zwykłymi poleceniami. Przypisy numerują się same i trafiają na dół strony:

#przyklad("Odnośnik: #link(\"https://typst.app\")[typst.app]. \
Przypis#footnote[Przypisy numerują się same.] jest na dole strony.")

= Matematyka

Wzory wpisujemy między znakami dolara. Zapis wygląda jak zwykły tekst, bez ukośników i klamer.
Gdy po otwarciu i przed zamknięciem dolara stoi spacja, wzór wyświetla się w osobnej linii:

#przyklad("$ sum_(k=1)^n k = (n (n+1)) / 2 $")

Wzory można numerować i się do nich odwoływać. Drgania tłumione, które narysujemy w dalszej części
dokumentu, opisuje wzór #ref(<rownanie>, supplement: none):

$ y(t) = A e^(-t slash tau) sin(omega t) $ <rownanie>

Tu $A$ oznacza amplitudę, $tau$ stałą czasową, a $omega$ pulsację. Pole pod obwiednią tych drgań wynosi
$ integral_0^infinity A e^(-t slash tau) dif t = A tau . $

= Kod z pliku zewnętrznego

Funkcja `read` wczytuje dowolny plik tekstowy, a `raw` formatuje go jako kod z kolorowaniem składni.
Poniższy skrypt Pythona nie jest wklejony do dokumentu, tylko wczytany z pliku `generuj_wykres.py`.
Dzięki temu kod w PDF-ie zawsze zgadza się z tym, który faktycznie narysował wykres:

#raw(read("generuj_wykres.py"), lang: "python", block: true)

= Obraz wygenerowany przez Pythona

Ten sam skrypt zapisał plik `wykres.png`, a Typst wstawia go poleceniem `image`. @wykres przedstawia przebieg
opisany wzorem #ref(<rownanie>, supplement: none) dla $A = 1$, $tau = 3$ i $omega = 2$.

#figure(
  image("wykres.png", width: 95%),
  caption: [Drgania tłumione narysowane w `matplotlib`, a osadzone w dokumencie Typst.],
) <wykres>

= Obliczenia w trakcie składania

Typst potrafi liczyć. Tabela poniżej nie została wpisana ręcznie, tylko obliczona z tego samego wzoru,
który narysował wykres. Zmiana parametru w kodzie zmienia całą tabelę:

#let amplituda = 1.0
#let stala-czasowa = 3.0
#let pulsacja = 2.0
#let drgania(t) = amplituda * calc.exp(-t / stala-czasowa) * calc.sin(pulsacja * t)

#przyklad(
  "#let r(t) = str(calc.round(y(t), digits: 3))
#table(
  columns: 4,
  align: center,
  [*t*], [*y(t)*], [*t*], [*y(t)*],
  ..for t in range(0, 4) { (str(t), r(t), str(t + 4), r(t + 4)) },
)",
  scope: (y: drgania),
  pionowo: true,
)

Pętle, warunki, funkcje, tablice i słowniki działają tak samo jak w innych językach programowania.
Ten sam mechanizm (funkcja `eval`) napędza przykłady w całym dokumencie: kod zapisany jako tekst jest
najpierw pokazany, a potem wykonany.

= Jeden plik, kilka stylów

Treść tego dokumentu leży w jednym pliku, a wygląd w osobnych konfiguracjach: `_styl_artykul.typ`
(kolorowy nagłówek i akcenty) oraz `_styl_latex.typ` (czcionka Computer Modern, wcięcia akapitów,
czarno-biały skład jak w LaTeX-u). Każda konfiguracja jest modułem, który eksportuje funkcję `styl`
i kilka ustawień, a o wyborze decyduje parametr z wiersza poleceń. Fragment tego pliku, który to robi,
wczytany z niego samego:

#let zrodlo = read("typst_w_pigulce.typ")
#raw(
  zrodlo.slice(zrodlo.position("#let style"), zrodlo.position("#show: s.styl")).trim(),
  lang: "typ",
  block: true,
)

Dzięki temu poprawka w treści trafia do wszystkich wersji naraz, a nowy wygląd to jeden dodatkowy plik.

= Jak powstał ten PDF

#table(
  columns: (auto, 1fr),
  stroke: none,
  fill: (_, y) => if calc.odd(y) { s.kolory.tlo },
  [*Krok*], [*Polecenie*],
  [1. Wykres], [`python3 generuj_wykres.py` zapisuje `wykres.png`],
  [2. Artykuł], [`typst compile --input styl=artykul typst_w_pigulce.typ ...`],
  [3. LaTeX], [`typst compile --input styl=latex typst_w_pigulce.typ ...`],
)

Pełna dokumentacja Typsta: #link("https://typst.app/docs")[typst.app/docs].
