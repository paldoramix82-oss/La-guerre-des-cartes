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
| HUD | `scripts/ui/hud.gd` | Aide et état des escouades sélectionnées |
| Tests | `tests/run_tests.gd` | 33 vérifications headless |

### Règles du GDD appliquées

- Escouade = entité contrôlable unique de N individus (§5).
- PV et dégâts individuels : 4 guerriers = 200 PV, 40 dégâts par attaque (§5.1).
- Un individu à 0 PV est retiré ; l'escouade existe tant qu'il reste un individu (§5.1).
- Pertes permanentes (§12.4).
- Mage : 2 cases horizontales **ou** verticales (§5.2). Cavalier : « Cercle 1 ».
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
| Armées de test | 1 escouade de chaque type (2 guerriers) par joueur | `main.gd: TEST_ARMY` |
| Contrôle des deux camps | Touche Tab (outil de test, pas d'IA adverse) | `SelectionController` |

## Questions ouvertes

1. **Mage « 10 (+2/T) »** : dégâts sur la durée (+2 par tour) ou bonus cumulatif ? Non implémenté.
2. **Soigneur** : le GDD indique « Dégâts 5, Zone 2, portée 3 » sans décrire de soin. Actuellement il inflige des dégâts ; faut-il qu'il soigne les alliés ?
3. **Cavalier « Cercle 1 »** : interprété comme toutes les cases adjacentes à l'escouade. Correct ?
4. **Ciblage dans une escouade** : quel individu reçoit les coups (premier, aléatoire, réparti) ?
5. **Plusieurs escouades sur une même case** : autorisé ? (actuellement oui, mais les ordres de groupe répartissent sur des cases distinctes).
6. **Mineur** : unité de combat ou unité économique (Prototype 2) ?

## Lancer

```bash
godot --path .                                      # jouer
godot --headless --path . -s res://tests/run_tests.gd  # tests
```
