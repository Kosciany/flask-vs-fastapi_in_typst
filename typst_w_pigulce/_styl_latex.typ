// Styl "jak w LaTeX-u": czcionka Computer Modern, wcięcia akapitów zamiast odstępów, szerokie marginesy.
// Czcionki tekstu i wzorów (New Computer Modern) są wbudowane w Typst, niczego nie trzeba instalować.
// Kod pisany jest wbudowanym DejaVu Sans Mono; wariant "New Computer Modern Mono" wymaga dodania czcionki (--font-path).
//
// Eksportuje to samo co _styl_artykul.typ: `styl`, `kolory` i `motyw`,
// więc w typst_w_pigulce.typ wybiera się go parametrem --input styl=latex.
// Samodzielnie:
//   #import "_styl_latex.typ": styl
//   #show: styl.with(title: "Tytuł", author: "Imię Nazwisko", date: datetime.today().display())
//
// (Przedrostek "_" w nazwie oznacza plik pomocniczy, a nie samodzielny dokument.)

// styl LaTeX-a jest czarno-biały: "akcent" to czerń, a tło przykładów to jasna szarość
#let kolory = (
  akcent: black,
  ciemny: black,
  tlo: luma(240),
)

#let motyw = (nazwa: "LaTeX")

#let styl(title: none, subtitle: none, author: none, date: none, body) = {
  set document(title: if title != none { title } else { auto })
  set page(paper: "a4", margin: 2.5cm, numbering: "1")
  set text(font: "New Computer Modern", size: 11pt, lang: "pl")
  set par(
    justify: true,
    leading: 0.55em,
    spacing: 0.65em,
    first-line-indent: (amount: 1.5em, all: true),
  )

  // nagłówki: pogrubione, szeryfowe, w kolorze tekstu, numerowane 1, 1.1, 1.1.1
  set heading(numbering: "1.1")
  show heading: set text(weight: "bold")
  show heading.where(level: 1): set text(size: 14.4pt)
  show heading.where(level: 2): set text(size: 12pt)
  show heading: set block(above: 1.4em, below: 1em)

  // kod, wzory, rysunki i listy
  show raw: set text(font: "DejaVu Sans Mono", size: 9pt)
  show raw.where(block: true): it => block(fill: luma(245), inset: 8pt, width: 100%, it)
  set table(stroke: 0.5pt, inset: 7pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  set math.equation(numbering: "(1)")
  set figure(gap: 1em)
  set list(indent: 1em)
  set enum(indent: 1em)

  // tytuł jak z \maketitle: wyśrodkowany, bez kolorowych elementów
  if title != none {
    align(center)[
      #v(1em)
      #text(size: 17.28pt, weight: "bold")[#title]
      #if subtitle != none [#v(0.6em) #text(size: 12pt, style: "italic")[#subtitle]]
      #if author != none [#v(1em) #text(size: 12pt)[#author]]
      #if date != none [#v(0.5em) #text(size: 12pt)[#date]]
      #v(1.5em)
    ]
  }

  body
}
