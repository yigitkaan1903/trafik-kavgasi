"""Fare imleçleri (piksel art, 2x büyütülmüş): ok ve tıklanabilir şeylerin üstünde el.

Çalıştırma (proje klasöründen):  python tools/make_cursors.py
Çıktı: assets/sprites/cursor_arrow.png, cursor_hand.png. Uç noktaları (hotspot) GameState.CURSORS ile aynı.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import write_png  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
SCALE = 2
PAL = {"k": (36, 22, 48, 255), "W": (255, 250, 236, 255), "g": (214, 200, 196, 255), "Y": (240, 190, 60, 255)}

ARROW = [   # küçük, yuvarlak hatlı ok; uçta altın parıltı
    "k.......",
    "kk......",
    "kYk.....",
    "kWWk....",
    "kWWWk...",
    "kWWWWk..",
    "kWWWWWk.",
    "kWWWkkkk",
    "kWkWk...",
    "kk.kWk..",
    "....kk..",
]

HAND = [   # tombul işaret parmağı, bilekte altın şerit
    "..kk......",
    ".kWWk.....",
    ".kWWkkk...",
    ".kWWWWWkk.",
    "kkWWgWgWWk",
    "kWkWWWWWWk",
    "kWWWWWWWWk",
    ".kWWWWWWWk",
    ".kWWWWWWk.",
    "..kYYYYYk.",
    "..kkkkkkk.",
]


def save(name, rows):
    w = len(rows[0])
    px = []
    for row in rows:
        assert len(row) == w, (name, row)
        line = []
        for ch in row:
            line += [PAL.get(ch, (0, 0, 0, 0))] * SCALE
        px += [line[:] for _ in range(SCALE)]
    write_png(os.path.join(OUT, name), px)


def main():
    save("cursor_arrow.png", ARROW)
    save("cursor_hand.png", HAND)
    print("İmleçler üretildi:", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
