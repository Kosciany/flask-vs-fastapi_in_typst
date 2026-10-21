"""Rysuje wykres drgań tłumionych do pliku wykres.png (obok tego skryptu).

Plik jest wczytywany do dokumentu typst_w_pigulce.typ jako zwykły tekst,
a wygenerowany przez niego obraz jest w tym dokumencie osadzony.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # bez okna: rysujemy wyłącznie do pliku
import matplotlib.pyplot as plt
import numpy as np

A, TAU, OMEGA = 1.0, 3.0, 2.0  # amplituda, stała czasowa, pulsacja

t = np.linspace(0, 12, 600)
obwiednia = A * np.exp(-t / TAU)
y = obwiednia * np.sin(OMEGA * t)

figure, ax = plt.subplots(figsize=(7, 3.2))
ax.plot(t, y, color="#0f766e", linewidth=2, label=r"$y(t)$")
ax.plot(t, obwiednia, "--", color="#d97706", label=r"$\pm A\,e^{-t/\tau}$")
ax.plot(t, -obwiednia, "--", color="#d97706")
ax.fill_between(t, -obwiednia, obwiednia, color="#d97706", alpha=0.08)
ax.axhline(0, color="gray", linewidth=0.8)
ax.annotate(
    "maksimum",
    xy=(t[np.argmax(y)], y.max()),
    xytext=(2.5, 0.85),
    arrowprops={"arrowstyle": "->"},
)
ax.set_xlabel("czas t")
ax.set_ylabel("wychylenie y")
ax.set_xlim(0, 12)
ax.legend(loc="upper right")
ax.grid(alpha=0.25)
figure.tight_layout()

figure.savefig(Path(__file__).with_name("wykres.png"), dpi=200)
