# Valeurs de jeu

Source : document de l'auteur « Le RTS » (`docs/sources/Le_RTS.pages`).
Données correspondantes : `data/units/*.tres`, `data/buildings/*.tres` (vérifiées par les tests).
Durées en **tours** (1 tour = `GameConfig.SECONDS_PER_TURN`).

## Temps

**1 tour = 20 secondes** (« pour le moment »). Production, construction, recrutement, consommation et
mana sont en tours ; le combat et les déplacements sont en secondes.

## Unités

| Unité | Effectif | PV | Dégâts / attaque | Intervalle | Portée | Déplacement (cases/s) | DPS d'escouade | Coût | Nourri / tour / individu |
|---|---|---|---|---|---|---|---|---|---|
| Guerrier | 4 | 50 | 5 | 2,5 s | 1 | 1,5 | 8 | 4 Nourri, 50 Gd | 2 |
| Archer | 2 | 30 | 10 | 3 s | 3 | 2 | 6,67 | 2 Nourri, 30 Gd | 1 |
| Cavalier | 2 | 100 | 15 (8 cases autour) | 4 s | 1 | 4 | 7,5 | 5 Nourri, 100 Gd | 3 |
| Mage | 1 | 25 | 6 + brûlure 2 PV/s pendant 4 s | 3 s | 2, zone 2 | 1 | — | 1 Nourri, 40 Gd | 1 |
| Soigneur | 1 | 35 | soin 5 | 3 s | 3, zone 2 | 2 | — | 1 Nourri, 30 Gd | 1 |
| Mineur | 1 | 50 | 5 | 3 s | 1 | 4 | 1,67 | 2 Nourri, 20 Gd | 2 |
| Ouvrier | 1 | 30 * | — | — | — | 2 * | — | (Cabane) | nourri par sa cabane |

\* provisoire. Coût de création **par escouade**. Vision = déplacement + 2 cases.
Brûlure : relancée (pas cumulée) par le même Mage ; deux Mages différents cumulent.
En combat, chaque individu vise l'ennemi le plus proche ; en déplacement, il contourne les cases occupées.
Archer, Mage et Soigneur **gardent leurs distances** : ils reculent quand un ennemi est plus près que leur portée.

Monstres : voir `docs/PROTOTYPE_4.md`.

## Bâtiments

| Type | Bâtiment | PV | Capacité | Production / tour | Coût | Tours de construction | « Cabane Garde » | Consommation / tour |
|---|---|---|---|---|---|---|---|---|
| Ressource | Bank | 250 | 2000 Gd | 0 | 200 Gd, 10 Bs, 5 Ml | 4 | 5 | 10 Nourri |
| Ressource | Moulin | 100 | 100 Nourri | 0 | 50 Gd, 5 Bs | 3 | 2 | 4 Nourri |
| Ressource | Entrepôt | 125 | 50 Bs, 25 Ml, 30 O | 0 | 100 Gd, 7 Bs, 2 Ml | 2 | 3 | 6 Nourri |
| Production | Culture | 50 | — | 10 Nourri | 20 Gd, 4 Bs, 2 O | 1 | 0 | 0 |
| Production | Ferme | 125 | — | 25 Nourri, 2 O | 50 Gd, 8 Bs, 6 O | 2 | 0 | 2 Nourri |
| Production | Mine | — | — | 5 Ml + 1 lingot (10 Gd) | 75 Gd, 5 Bs, 3 Ml (exploitation) | 2 | 0 | 3 Nourri |
| Logement | Cabane Ouvrier | — | 1 ouvrier | — | 2 Bs | immédiate | — | 3 Nourri |
| Logement | Maison | — | +5 habitants | — | 30 Gd, 5 Bs * | 1 * | — | 2 Nourri |
| Militaire | Caserne | — | — | — | 100 Gd | — | — | — |

Caserne — cadence de recrutement par tour : 4 Guerriers, 2 Archers, 2 Cavaliers, 2 Mineurs, 1 Soigneur, 1 Mage.
Capacité : 25 individus en file ; annulation remboursée.

## Défenses

| Défense | PV | Dégâts | Portée | Consommation / tour | Coût | Tours de construction |
|---|---|---|---|---|---|---|
| Tour Archer | 100 | 20 | 7 | 2 Nourri | 4 Bs, 2 Ml, 60 Gd | 3 |
| Canon | 150 | 40 | 4 | 0 | 2 Bs, 5 Ml, 100 Gd | 4 |
| Cabane Garde | 2 × 50 | 2 × 10 | 3 | 2 Nourri | 2 Bs, 20 Gd | 1 |
| Barricade | 50 | 0 | 2 L | 0 | 1 Bs, 1 Ml, 10 Gd | 0 |
| Mortier | 125 | 30 | 2 à 6 (zone 2) | 0 | 6 Bs, 4 Ml, 125 Gd | 4 |

## Siège

| Machine | PV | Dégâts | Portée | Unités | Déplacement | Coût | Tours de construction |
|---|---|---|---|---|---|---|---|
| Échelle | 0 | 0 | 1 | 1 | 0 | 1 Bs, 5 Gd | 0 |
| Canon | 75 | 75 | 1 | 2 | 2 | 2 Bs, 1 Ml, 120 Gd | 2 |

## Décisions de l'auteur

- Départ : 1000 Gd, 50 Nourri, 10 O, 20 Bs, 10 Ml ; **50 habitants** ; **2 Cabanes Ouvrier** déjà construites.
- Stockage de base : 2000 Gd, 50 Bs, 25 Ml, 25 O, 100 Nourri.
- **Arbre** : 20 bois au total, 10 par tour ; **baies** : 10 Nourri, finies en un tour.
- **Or et métal** : uniquement dans les mines (inépuisables) : 5 Ml + 1 lingot (= 10 Gd) par cycle.
- **Habitants** : ils deviennent ouvriers et soldats ; Maison = +5 habitants, 2 Nourri / tour.
- **Travaux** : chaque ouvrier en plus divise le temps par 2 (1 : normal, 2 : moitié, 3 : quart).
- **Arbres** : l'avancement de la récolte appartient à l'arbre (il ne repart pas de zéro).
- **Mines** : un cycle de production (5 Ml + 1 lingot) toutes les 20 s, 15 s / 12 s / 10 s avec
  1 / 2 / 3 mineurs ; 3 mineurs au plus par mine.
- **Maison** : les 5 habitants arrivent d'un coup.
- **Ouvriers** : 1 par cabane, nourri par elle ; un ouvrier libre part construire seul ; on peut le
  réaffecter ; pendant un combat, il se cache dans sa cabane.
- **Rationnement** : sous 20 % de nourriture, seules les escouades choisies avec « Nourrir » sont servies
  (les bâtiments sont toujours servis d'abord).
- **Mana** : 5 par tour, maximum 20. **Cristaux de mana** : laissés par les créatures magiques (golem),
  pour les bâtiments de mana.
- **Organique** : Ferme (2 / tour) et animaux de la forêt.
- Sans nourriture : bâtiments et unités s'arrêtent.
- Le jeu sera à terme en **vue isométrique**, en pixel art ; l'auteur dessinera le plan de la carte.
