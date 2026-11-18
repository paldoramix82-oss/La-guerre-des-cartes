# Valeurs de jeu

Source : document de l'auteur « Le RTS » (`docs/sources/Le_RTS.pages`).
Données correspondantes : `data/units/*.tres`, `data/buildings/*.tres` (vérifiées par les tests).
Durées en **tours** (1 tour = `GameConfig.SECONDS_PER_TURN`).

## Unités

| Unité | PV | Dégâts | Portée | Déplacement | Coût de création | Effectif |
|---|---|---|---|---|---|---|
| Guerrier | 50 | 10 | 1 | 1 | 4 Nourri, 50 Gd | 4 |
| Archer | 30 | 20 | 3 | 2 | 2 Nourri, 30 Gd | 2 |
| Cavalier | 75 | 15 | 1 en cercle | 4 | 5 Nourri, 100 Gd | 2 |
| Mage | 25 | 10 + brûlure 2/T pendant 2 T | 2, zone 2 | 1 | 1 Nourri, 40 Gd | 1 |
| Soigneur | 35 | soin 5 | 3, zone 2 | 2 | 1 Nourri, 30 Gd | 1 |
| Mineur | 50 | 5 | 1 | 4 | 2 Nourri, 20 Gd | 1 |

## Bâtiments

| Type | Bâtiment | PV | Capacité | Production / tour | Coût | Tours de construction | « Cabane Garde » | Consommation / tour |
|---|---|---|---|---|---|---|---|---|
| Ressource | Bank | 250 | 2000 Gd | 0 | 200 Gd, 10 Bs, 5 Ml | 4 | 5 | 10 Nourri |
| Ressource | Moulin | 100 | 100 Nourri | 0 | 50 Gd, 5 Bs | 3 | 2 | 4 Nourri |
| Ressource | Entrepôt | 125 | 50 Bs, 25 Ml, 30 O | 0 | 100 Gd, 7 Bs, 2 Ml | 2 | 3 | 6 Nourri |
| Production | Culture | 50 | — | 10 Nourri | 20 Gd, 4 Bs, 2 O | 1 | 0 | 0 |
| Production | Ferme | 125 | — | 25 Nourri | 50 Gd, 8 Bs, 6 O | 2 | 0 | 2 Nourri |
| Production | Mine | ??? | — | ??? | 75 Gd, 5 Bs, 3 Ml | 2 | 0 | 3 Nourri |
| Logement | Cabane Ouvrier | — | 2 ouvriers | — | 2 Bs | — | — | 3 Nourri |
| Militaire | Caserne | — | — | — | 100 Gd | — | — | — |

Caserne — cadence de recrutement par tour : 4 Guerriers, 2 Archers, 2 Cavaliers, 2 Mineurs, 1 Soigneur, 1 Mage.

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

## Décisions de l'auteur (Prototype 2)

- Départ : 1000 Gd, 50 Nourri, 10 O, 20 Bs, 10 Ml.
- Stockage de base (sans Bank / Moulin / Entrepôt) : 2000 Gd, 50 Bs, 25 Ml, 25 O, 100 Nourri.
- Récolte **sur place** : un ouvrier récolte 2 par tour (métal). Gisements épuisables.
- Gisements : forêt (bois, et nourriture), filons de métal, gisements d'or ; nourriture aussi ailleurs.
- Or : gisements d'or, mines, pillage, butins de boss et de monstres.
- Mines : pas de PV, indestructibles ; se capturent (siège) et se reprennent ; produisent un peu d'or et de métal.
- Cabane Ouvrier : pas de PV, construite d'un coup ; les 3 Nourri / tour sont une **consommation**.
- Caserne : 4 tours de construction, pas de PV, indestructible.
- « Cabane Garde » : nombre de cabanes de garde fournies autour du bâtiment pour le protéger.
- Construction : il faut des ouvriers ; plus il y en a, plus c'est rapide.
- Sans nourriture : bâtiments, ouvriers, gardes et unités s'arrêtent de fonctionner.

## Encore à définir

- Quantité de chaque gisement ; récolte par tour du bois, de la nourriture et de l'or.
- Source de l'Organique.
- PV et vitesse de l'ouvrier.
- Mine : production exacte (or, métal).
- Consommation de nourriture des unités militaires.
- Barricade « 2 L ».
