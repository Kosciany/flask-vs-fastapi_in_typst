// Szablon: ARTYKUŁ (raport, skrypt, instrukcja)
// Użycie:
//   #import "szablon_artykul.typ": szablon-artykul
//   #show: szablon-artykul.with(title: "...", subtitle: "...", date: "...")
//
// Czcionki: Liberation Sans (tekst) i JetBrains Mono (kod); trzeba je mieć zainstalowane.

#let szablon-artykul(
  title: "",
  subtitle: none,
  date: none,
  author: none,
  body,
) = {
  // --- Strona i czcionki ---
  set page(
    paper: "a4",
    margin: (x: 2.5cm, top: 2.5cm, bottom: 2.5cm),
    numbering: "1 / 1",
  )
  set text(font: "Liberation Sans", size: 11pt, lang: "pl")
  set par(justify: true, leading: 0.65em)

  // --- Nagłówki ---
  show heading: set text(weight: "bold", fill: rgb("#1a3a5f"))
  show heading.where(level: 1): it => block(above: 1.5em, below: 0.6em, it)

  // --- Listy: trochę więcej oddechu między punktami ---
  set list(spacing: 0.9em)
  set enum(spacing: 0.9em)

  // --- Linki: widoczne, w kolorze marki ---
  show link: set text(fill: rgb("#1a5fb4"))

  // --- Tabele: lekka, czytelna siatka ---
  set table(
    stroke: 0.5pt + rgb("#dee2e6"),
    inset: 7pt,
  )
  show table.cell.where(y: 0): set text(weight: "bold")

  // --- Cytaty / notki (blockquote z Markdowna) ---
  set quote(block: true)
  show quote: it => block(
    fill: rgb("#fff8e1"),
    stroke: (left: 3pt + rgb("#f0ad4e")),
    inset: 10pt,
    radius: 3pt,
    width: 100%,
    it.body,
  )

  // --- Bloki kodu (odpowiednik minted/listings z LaTeX) ---
  show raw.where(block: true): it => block(
    fill: rgb("#f8f9fa"),
    inset: 12pt,
    radius: 6pt,
    width: 100%,
    stroke: 0.5pt + rgb("#e9ecef"),
    breakable: true,
    it,
  )
  // Kod inline: subtelne tło
  show raw.where(block: false): it => box(
    fill: rgb("#f1f3f5"),
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 2pt,
    it,
  )
  show raw: set text(font: "JetBrains Mono", size: 9.5pt)

  // --- Nagłówek dokumentu ---
  v(0.5cm)
  align(center)[
    #text(size: 22pt, weight: "bold", fill: rgb("#1a3a5f"))[#title]
    #if subtitle != none [
      #v(0.4em)
      #text(size: 14pt, style: "italic", fill: gray.darken(20%))[#subtitle]
    ]
    #if author != none [
      #v(0.8em)
      #text(size: 11pt)[#author]
    ]
    #if date != none [
      #v(0.5em)
      #text(size: 10pt, fill: gray.darken(20%))[#date]
    ]
  ]
  v(1.2cm)

  body
}
