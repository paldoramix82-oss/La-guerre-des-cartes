# La Guerre des Cartes

RTS 1v1 mêlant gestion de royaume, jungle façon MOBA, deckbuilding et héros — Godot 4.

- Conception : [`docs/GDD.md`](docs/GDD.md)
- Prototype 1 (carte, déplacements, sélection, combats) — [`docs/PROTOTYPE_1.md`](docs/PROTOTYPE_1.md)
- **Prototype 2** (ressources, ouvriers, constructions) — [`docs/PROTOTYPE_2.md`](docs/PROTOTYPE_2.md)
- **Prototype 3** (recrutement, nourriture des unités) — [`docs/PROTOTYPE_3.md`](docs/PROTOTYPE_3.md)
- **Prototype 4** (monstres, mines) — [`docs/PROTOTYPE_4.md`](docs/PROTOTYPE_4.md)
- **Prototype 7** (défenses, bâtiments attaquables — en cours) — [`docs/PROTOTYPE_7.md`](docs/PROTOTYPE_7.md)
- **Prototype 5** (mana, cartes) — [`docs/PROTOTYPE_5.md`](docs/PROTOTYPE_5.md)
- **Questions en attente** — [`docs/QUESTIONS.md`](docs/QUESTIONS.md)
- Carte immense et brouillard de guerre — [`docs/CARTE.md`](docs/CARTE.md)
- Valeurs de jeu — [`docs/VALEURS.md`](docs/VALEURS.md)

## Démarrage

1. Installer [Godot 4.3+](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir `project.godot` dans Godot (le premier import des assets prend quelques secondes), puis F5 — ou `godot --path .`.

Jouable entièrement au trackpad (Mac), sans clic droit ni molette :

| Action | Contrôle |
|---|---|
| Choisir une escouade | Clic dessus (Maj + clic : ajouter / retirer) |
| Choisir plusieurs escouades | Glisser un rectangle · bouton ⬚ (Cmd + A) |
| Déplacer | Escouade choisie, puis clic sur le terrain |
| Attaquer | Escouade choisie, puis clic sur un ennemi |
| Soigner (Soigneur) | Option + clic sur un allié |
| Construire | Onglet **Construction** (en bas), puis clic dans votre royaume |
| Recruter | Clic sur votre Caserne, puis une unité de l'onglet **Recrutement** |
| Nourrir en priorité | Escouades choisies, puis bouton rond du milieu (commandes) |
| Exploiter une mine capturée | Clic sur la mine, onglet Construction : Exploiter |
| Attaquer un bâtiment | Escouades choisies, puis clic sur le bâtiment ennemi |
| Annuler un recrutement | Caserne choisie, bouton ⊘ |
| Jouer une carte | Clic sur la carte (Destruction / Bannissement : puis clic sur la carte cible) |
| Récolter / aider à construire | Ouvriers choisis, puis clic sur un gisement / un chantier |
| Déplacer / attaquer (en deux temps) | Bouton ✥ ou ⚔ du panneau de commandes, puis clic |
| Stop / annuler | Main ✋ (Espace) / ⊘ (Échap) |
| Pause / accélérer | Boutons en haut à droite (touche P) |
| Déplacer la vue | Glisser à deux doigts · flèches · ZQSD (AZERTY) / WASD |
| Zoom / vue | Pincer · **+** / **−** près de la mini-carte · clic sur la mini-carte |
| Contrôler l'autre joueur (test) | Touche Tab |

Le clic droit (ou clic à deux doigts) reste disponible comme ordre direct.

## Tests

```bash
tests/run.sh /chemin/vers/godot   # échoue aussi s'il y a la moindre erreur de script
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
