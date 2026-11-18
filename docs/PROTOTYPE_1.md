# Prototype 1 — Carte, déplacements, sélection, combats

Périmètre (GDD §14) : une carte, des escouades qui se déplacent, se sélectionnent et combattent.
Hors périmètre : ressources, bâtiments, recrutement, jungle/monstres, mana, cartes, héros, château/roi.

## Ce qui est implémenté

| Système | Fichier | Contenu |
|---|---|---|
| Configuration | `scripts/core/game_config.gd` | Toutes les constantes techniques, valeurs provisoires signalées |
| Données d'unités | `scripts/data/unit_data.gd`, `data/units/*.tres` | Les 6 unités du GDD §5.1, valeurs inchangées |
| Registre | `scripts/data/unit_database.gd` | Charge automatiquement tout `.tres` de `data/units/` |
| Carte | `scripts/map/game_map.gd` | Grille, terrains, A* (AStarGrid2D), conversions case/monde |
| Escouades | `scripts/units/squad.gd` | PV individuels, retrait des morts, déplacement, ordres |
| Combat | `scripts/combat/combat_system.gd` | Portée, géométries d'attaque (simple / cercle / ligne), résolution |
| Contrôles | `scripts/controls/*.gd` | Sélection clic / rectangle, ordres clic droit, caméra |
| Rendu de la carte | `scripts/map/map_renderer.gd` | Sol, arbres/rochers sur les obstacles, décorations (purement visuel) |
| HUD | `scripts/ui/hud.gd`, `assets/ui/theme.tres` | Aide, cartes des escouades sélectionnées avec portrait |
| Écran titre | `scenes/title.tscn`, `scripts/ui/title_screen.gd` | Fond, boutons Jouer / Quitter |
| Musique | `scripts/ui/music_player.gd` | Une piste en boucle par scène (`GameConfig.MUSIC_*`) |
| Tests | `tests/run_tests.gd` | 72 vérifications headless (dont compilation de tous les scripts) |

### Règles du GDD appliquées

- Escouade = entité contrôlable unique de N individus (§5).
- PV et dégâts individuels : 4 guerriers = 200 PV, 40 dégâts par attaque (§5.1).
- Un individu à 0 PV est retiré ; l'escouade existe tant qu'il reste un individu (§5.1).
- Pertes permanentes (§12.4).
- Mage : 2 cases horizontales **ou** verticales (§5.2), 10 dégâts + brûlure de 2 dégâts par tour pendant 2 tours.
- Soigneur : soigne 5 PV aux alliés de sa zone (Zone 2, portée 3), n'attaque pas. Il soigne
  automatiquement un allié blessé à portée ; clic droit sur un allié pour lui donner l'ordre.
- Mineur : combat normalement ; la capacité de minage est déclarée (`can_mine`) et sera branchée
  au Prototype 2 avec les ressources et les mines.
- Cavalier : « Cercle 1 ».
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
| Répartition des coups | Chaque coup frappe le premier individu vivant ; pas de report des dégâts excédentaires | `Squad.take_hits` |
| Ciblage automatique | Une escouade inactive attaque l'ennemi le plus proche à portée, sans le poursuivre | `Squad._auto_acquire` |
| Direction de la zone du Mage | Axe dominant attaquant → cible, à partir de la case ciblée | `CombatSystem.affected_cells` |
| Portée d'attaque du Mage | 1 (la colonne « Portée » indique seulement « Zone 2 ») | `data/units/mage.tres` |
| Brûlure : cible des dégâts | Chaque tour, 1 coup de 2 dégâts par individu Mage, sur le premier individu vivant | `Squad.apply_burn` |
| Brûlure : nouvel impact | Une nouvelle brûlure du Mage remplace la précédente (pas de cumul) ; 1er tick un tour après l'impact | `Squad.apply_burn` |
| Soin : répartition | 5 PV par individu Soigneur, donnés à l'individu le plus blessé ; plafonnés aux PV max ; pas de résurrection | `Squad.heal` |
| Soin : zone | Même géométrie « Zone 2 » que le Mage, appliquée aux alliés | `CombatSystem.perform_heal` |
| Cadence du soin | Comme l'attaque : 1 par tour | `GameConfig.ATTACK_INTERVAL_TURNS` |
| Armées de test | 1 escouade de chaque type (2 guerriers) par joueur | `main.gd: TEST_ARMY` |
| Contrôle des deux camps | Touche Tab (outil de test, pas d'IA adverse) | `SelectionController` |

## Questions résolues

- Mage « +2/T » : brûlure de 2 dégâts par tour pendant 2 tours.
- Soigneur : la valeur 5 est un soin.
- Mineur : combat et minage.

## Questions ouvertes

1. **Cavalier « Cercle 1 »** : interprété comme toutes les cases adjacentes à l'escouade. Correct ?
2. **Ciblage dans une escouade** : quel individu reçoit les coups (premier, aléatoire, réparti) ?
3. **Plusieurs escouades sur une même case** : autorisé ? (actuellement oui, mais les ordres de groupe répartissent sur des cases distinctes).
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
godot --path .                                      # jouer
godot --headless --path . -s res://tests/run_tests.gd  # tests
```
