# Prototype 1 — Carte, déplacements, sélection, combats

Périmètre (GDD §14) : une carte, des escouades qui se déplacent, se sélectionnent et combattent.
Hors périmètre : ressources, bâtiments, recrutement, jungle/monstres, mana, cartes, héros, château/roi.

## Ce qui est implémenté

| Système | Fichier | Contenu |
|---|---|---|
| Configuration | `scripts/core/game_config.gd` | Toutes les constantes techniques, valeurs provisoires signalées |
| Données d'unités | `scripts/data/unit_data.gd`, `data/units/*.tres` | Les 6 unités du GDD §5.1, valeurs inchangées |
| Registre | `scripts/data/unit_database.gd` | Charge automatiquement tout `.tres` de `data/units/` |
| Carte | `scripts/map/game_map.gd` | Grille, terrains, A* (AStarGrid2D), occupation des cases (un individu par case) |
| Escouades | `scripts/units/squad.gd` | Entité contrôlable : reçoit les ordres et les répartit entre ses individus |
| Individus | `scripts/units/individual.gd` | Une case par individu : PV, déplacement, action, brûlure, rendu |
| Combat | `scripts/combat/combat_system.gd` | Portée, géométries d'attaque (simple / cercle / ligne), résolution |
| Contrôles | `scripts/controls/*.gd` | Un seul bouton (trackpad) : clic = choisir puis clic = ordre ; caméra au geste (deux doigts, pincer) ; repère visuel des ordres |
| Rendu de la carte | `scripts/map/map_renderer.gd` | Sol, arbres/rochers sur les obstacles, décorations (purement visuel) |
| HUD | `scripts/ui/hud.gd`, `assets/ui/theme.tres` | Aide, cartes des escouades sélectionnées avec portrait |
| Écran titre | `scenes/title.tscn`, `scripts/ui/title_screen.gd` | Fond, boutons Jouer / Quitter |
| Musique | `scripts/ui/music_player.gd` | Une piste en boucle par scène (`GameConfig.MUSIC_*`) |
| Tests | `tests/run_tests.gd`, `tests/run.sh` | 90 vérifications headless (compilation, bataille complète avec libération réelle des unités mortes, commandes) ; `run.sh` échoue sur toute erreur de script |

### Règles du GDD appliquées

- Escouade = entité contrôlable unique de N individus (§5).
- **Chaque individu occupe sa propre case** (précision de l'auteur) : une escouade de 4 guerriers
  occupe 4 cases. Portées et zones se calculent depuis la case de chaque individu.
- PV et dégâts individuels : 4 guerriers = 200 PV, 40 dégâts par attaque (§5.1).
- Un individu à 0 PV est retiré ; l'escouade existe tant qu'il reste un individu (§5.1).
- Pertes permanentes (§12.4).
- Mage : 2 cases horizontales **ou** verticales (§5.2) ; chaque individu sur ces cases subit 10 dégâts
  puis une brûlure de 2 dégâts par tour pendant 2 tours.
- Soigneur : chaque allié sur les 2 cases de sa zone récupère 5 PV (portée 3), il n'attaque pas. Il soigne
  automatiquement un allié blessé à portée ; clic droit sur un allié pour lui donner l'ordre.
- Mineur : combat normalement ; la capacité de minage est déclarée (`can_mine`) et sera branchée
  au Prototype 2 avec les ressources et les mines.
- Cavalier : « Cercle 1 » = chaque individu ennemi sur les 8 cases autour du cavalier.
- Valeurs en tours converties en secondes via `GameConfig.SECONDS_PER_TURN` (§1.2).

## Valeurs et choix PROVISOIRES (à valider par le game designer)

Ces choix ne sont pas définis par le GDD (§13) ; ils sont centralisés pour être changés facilement.

| Sujet | Valeur actuelle | Où la changer |
|---|---|---|
| Durée d'un tour | 1 s | `GameConfig.SECONDS_PER_TURN` |
| Cadence d'attaque | 1 attaque / tour | `GameConfig.ATTACK_INTERVAL_TURNS` |
| Vitesse réelle | Déplacement GDD = cases par tour | `GameConfig.move_speed_px` |
| Carte | 60 × 36 cases, royaumes de 14 cases, rivière centrale à 3 gués, rochers symétriques | `GameConfig`, `GameMap.generate_placeholder_layout` |
| Mesure des portées | Distance de Chebyshev (diagonale = 1 case) | `CombatSystem.grid_distance` |
| Choix de la cible | Chaque individu vise l'individu valide le plus proche de l'escouade ciblée (à portée en priorité) | `Individual._pick_target` |
| Occupation pendant le déplacement | Les individus peuvent traverser des cases occupées ; seules les cases d'arrêt sont exclusives | `GameMap.reserve` |
| Formation | Les individus se placent autour du point visé, cases orthogonales d'abord | `GameMap.spread_cells` |
| Poursuite | Chaque individu hors de portée rejoint la case libre à portée la plus proche de sa cible | `Individual._approach` |
| Ciblage automatique | Une escouade inactive agit sur l'escouade dont un individu est à portée d'un des siens, sans poursuite | `Squad._auto_acquire` |
| Direction de la zone du Mage | Axe dominant attaquant → cible, à partir de la case ciblée | `CombatSystem.affected_cells` |
| Portée d'attaque du Mage | 1 (la colonne « Portée » indique seulement « Zone 2 ») | `data/units/mage.tres` |
| Brûlure : nouvel impact | Une nouvelle brûlure du Mage sur un individu remplace la précédente (pas de cumul) ; 1er tick un tour après l'impact | `Individual.apply_burn` |
| Soin : zone | Même géométrie « Zone 2 » que le Mage, appliquée aux alliés ; plafonné aux PV max ; pas de résurrection | `CombatSystem.perform_action` |
| Cadence du soin | Comme l'attaque : 1 par tour | `GameConfig.ATTACK_INTERVAL_TURNS` |
| Armées de test | 1 escouade de chaque type (2 guerriers) par joueur | `main.gd: TEST_ARMY` |
| Contrôle des deux camps | Touche Tab (outil de test, pas d'IA adverse) | `SelectionController` |

## Questions résolues

- Mage « +2/T » : brûlure de 2 dégâts par tour pendant 2 tours.
- Soigneur : la valeur 5 est un soin.
- Mineur : combat et minage.
- Placement : un individu par case.
- Plusieurs individus sur une même case : non (une case = un individu).

## Questions ouvertes

1. **Cavalier « Cercle 1 »** : interprété comme les 8 cases autour de chaque cavalier. Correct ?
2. **Ciblage** : chaque individu vise l'individu ennemi le plus proche. Correct ?
3. **Cases occupées en mouvement** : un individu peut-il traverser une case occupée (actuellement oui) ?
4. **Brûlure** : plusieurs Mages / plusieurs impacts doivent-ils cumuler leurs brûlures ?
5. **Portée d'attaque du Mage** : toujours non précisée (1 case actuellement).

## Assets

Pack fourni par l'auteur, dans `assets/` (sprites 16/24 px, interface, polices OFL, musiques).
Correspondance des unités (modifiable dans chaque `data/units/*.tres`) :

| Unité | Sprite |
|---|---|
| Guerrier | `guerrier` |
| Archer | `chasseur` |
| Cavalier | `capitaine` (stand-in : pas de cavalier monté dans le pack) |
| Mage | `mage` |
| Soigneur | `soigneur` |
| Mineur | `briseur` |

Le logo `ui/title_logo.png` porte le nom d'un autre jeu (« Legenders ») : il n'est pas utilisé ;
l'écran titre affiche « La Guerre des Cartes » avec la police Cinzel du pack.
Les tentes et bannières des royaumes sont décoratives (pas de bâtiments avant le Prototype 2).

## Lancer

```bash
godot --path .              # jouer (fenêtre agrandie, l'affichage s'adapte à sa taille)
tests/run.sh <godot>        # tests
```

## Corrections

- Plantage « Invalid type in function '_is_valid_target' … previously freed » : une unité visait
  un ennemi mort et déjà supprimé. Les vérifications d'existence sont faites avant tout appel,
  et les tests libèrent désormais réellement les unités mortes pour attraper ce type de bug.
