# La Guerre des Cartes

RTS 1v1 mêlant gestion de royaume, jungle façon MOBA, deckbuilding et héros — Godot 4.

- Conception : [`docs/GDD.md`](docs/GDD.md)
- État actuel : **Prototype 1** (carte, déplacements, sélection, combats) — [`docs/PROTOTYPE_1.md`](docs/PROTOTYPE_1.md)

## Démarrage

1. Installer [Godot 4.3+](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir `project.godot` dans Godot (le premier import des assets prend quelques secondes), puis F5 — ou `godot --path .`.

| Action | Contrôle |
|---|---|
| Sélectionner | Clic gauche / glisser un rectangle (Maj pour ajouter) |
| Déplacer / attaquer / soigner | Clic droit sur le sol / un ennemi / un allié (Soigneur) |
| Stop / désélectionner | Espace / Échap |
| Caméra | ZQSD (AZERTY) ou WASD, flèches, molette, clic molette |
| Changer d'équipe contrôlée (test) | Tab |

## Tests

```bash
godot --headless --path . -s res://tests/run_tests.gd
```

## Organisation

```
assets/            Sprites, interface (theme.tres), polices, musiques
data/units/        Définitions d'unités (.tres) — ajouter une unité = ajouter un fichier
docs/              GDD et notes de prototype
scenes/            title.tscn (écran titre, scène de lancement), main.tscn (partie)
scripts/
  core/            Configuration globale (valeurs provisoires centralisées)
  data/            Classes de données et registres
  map/             Grille, terrain, pathfinding
  units/           Escouades
  combat/          Règles de combat
  controls/        Sélection, ordres, caméra
  ui/              HUD
tests/             Tests headless
```
