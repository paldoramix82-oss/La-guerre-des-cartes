#!/usr/bin/env python3
"""Découpe l'interface de la maquette (assets/ui/mockup/interface_mockup.png) en
éléments PNG transparents utilisables par le HUD (assets/ui/hud/).

- Le fond en damier, peint dans l'image, est retiré par remplissage depuis les bords.
- Le texte d'exemple de la maquette (chiffres, objectifs factices, libellés d'onglets)
  est effacé : le jeu affiche ses propres valeurs par-dessus.

Usage : python3 tools/extract_ui.py   (nécessite Pillow)
Les coordonnées sont celles de la maquette (1672 x 941), qui sert aussi de
résolution de base au HUD.
"""
import collections
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets/ui/mockup/interface_mockup.png")
OUT = os.path.join(ROOT, "assets/ui/hud")

# nom : (x0, y0, x1, y1) inclusifs
CROPS = {
    "logo": (14, 13, 424, 238),
    "resource_bar": (431, 13, 1280, 73),
    "icon_gold": (462, 28, 496, 63),
    "icon_wood": (622, 28, 664, 62),
    "icon_food": (775, 28, 817, 62),
    "icon_mana": (934, 26, 973, 64),
    "icon_population": (1110, 28, 1158, 62),
    "clock": (1341, 17, 1459, 71),
    "btn_pause": (1482, 17, 1537, 71),
    "btn_fast": (1540, 17, 1595, 71),
    "btn_settings": (1599, 17, 1654, 71),
    "minimap": (1341, 79, 1656, 286),
    "objectives": (1342, 294, 1656, 425),
    "icon_objective": (1371, 341, 1399, 369),
    "hand": (1318, 462, 1661, 649),
    "pause_menu": (24, 249, 305, 566),
    "portrait": (9, 642, 342, 916),
    "info": (354, 690, 941, 912),
    "tabs_panel": (953, 683, 1379, 912),
    "tab_active": (967, 684, 1086, 725),
    "tab_inactive": (1092, 684, 1211, 725),
    "commands": (1391, 684, 1658, 916),
}

# Zones de texte d'exemple à effacer (coordonnées maquette).
# La zone doit rester à l'intérieur du panneau : la ligne juste au-dessus et
# celle juste en dessous servent de référence de couleur.
ERASE = [
    (452, 24, 1258, 66),     # barre de ressources : chiffres et icônes d'exemple
    (1388, 27, 1452, 59),    # horloge : « 12:34 »
    (1360, 336, 1642, 408),  # objectifs factices
    (975, 692, 1078, 718),   # libellé de l'onglet actif
    (1100, 692, 1203, 718),  # libellé d'un onglet inactif
    (1225, 692, 1330, 718),  # libellé du 3e onglet
]


def is_background(p):
    r, g, b = p[:3]
    return min(r, g, b) >= 150 and max(r, g, b) - min(r, g, b) <= 22


def remove_background(im):
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = collections.deque()
    for x in range(w):
        q.extend([(x, 0), (x, h - 1)])
    for y in range(h):
        q.extend([(0, y), (w - 1, y)])
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i] or not is_background(px[x, y]):
            continue
        seen[i] = 1
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))


def erase(im, box):
    """Efface la zone : chaque colonne devient un dégradé entre le pixel juste
    au-dessus et celui juste en dessous (le fond du panneau)."""
    px = im.load()
    x0, y0, x1, y1 = box
    n = y1 - y0 + 2
    for x in range(x0, x1 + 1):
        top, bottom = px[x, y0 - 1], px[x, y1 + 1]
        for y in range(y0, y1 + 1):
            t = (y - y0 + 1) / n
            px[x, y] = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(4))


def main():
    os.makedirs(OUT, exist_ok=True)
    base = Image.open(SRC).convert("RGBA")
    remove_background(base)
    # Les icônes sont découpées AVANT l'effacement du texte.
    icons = {n: base.crop((b[0], b[1], b[2] + 1, b[3] + 1)) for n, b in CROPS.items() if n.startswith("icon_")}
    for box in ERASE:
        erase(base, box)
    for name, b in CROPS.items():
        img = icons.get(name) or base.crop((b[0], b[1], b[2] + 1, b[3] + 1))
        img.save(os.path.join(OUT, name + ".png"))
        print(f"{name:18s} {img.size}")


if __name__ == "__main__":
    main()
