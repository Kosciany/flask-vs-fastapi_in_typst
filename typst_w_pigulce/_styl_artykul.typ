// Konfiguracja "artykuł": strona A4, czytelny tekst, kolorowy nagłówek.
// Każda konfiguracja eksportuje to samo: funkcję `styl`, słownik `kolory` (kolory, których używa treść)
// i słownik `motyw` (nazwa stylu, wstawiana do tekstu).

#let kolory = (
  akcent: rgb("#0f766e"),
  ciemny: rgb("#134e4a"),
  tlo: rgb("#f0fdfa"),
)

#let motyw = (nazwa: "artykuł")

#let styl(title: none, subtitle: none, body) = {
  set document(title: title)
  set page(
    paper: "a4",
    margin: (x: 2.2cm, y: 1.9cm),
    footer: context [
      #set text(size: 8.5pt, fill: gray)
      #title #h(1fr) strona #counter(page).display() z #counter(page).final().first()
    ],
  )
  set text(font: "Liberation Sans", size: 10.5pt, lang: "pl")
  set par(justify: true, leading: 0.65em)
  set heading(numbering: "1.")
  show heading: set text(fill: kolory.akcent)
  show heading.where(level: 1): set block(above: 1.6em, below: 0.8em)
  show link: set text(fill: kolory.akcent)
  show raw: set text(font: "JetBrains Mono", size: 8.5pt)
  show raw.where(block: true): it => block(
    fill: luma(246),
    stroke: (left: 2.5pt + kolory.akcent),
    inset: 10pt,
    radius: (right: 4pt),
    width: 100%,
    it,
  )
  set math.equation(numbering: "(1)")
  set figure(gap: 0.9em)
  show figure.caption: set text(size: 9pt, style: "italic")
  set table(stroke: 0.6pt + kolory.akcent.lighten(40%), inset: 8pt)
  show table.cell.where(y: 0): set text(weight: "bold")

  align(center)[
    #block(
      fill: gradient.linear(kolory.akcent, kolory.ciemny, angle: 20deg),
      inset: (x: 1.5cm, y: 1.1cm),
      radius: 8pt,
      width: 100%,
    )[
      #text(size: 28pt, weight: "bold", fill: white)[#title]
      #if subtitle != none [
        #v(0.2em)
        #text(size: 12pt, fill: white.darken(10%))[#subtitle]
      ]
    ]
  ]
  v(0.6cm)

  body
}
