# Prototype 4 — Jungle, monstres et mines

Boss (Dragon, Sorcière) : reportés par l'auteur. Récompenses en cartes : plus tard.

## Monstres (`data/monsters/`, `data/camps/`, `scripts/world/monster_camp.gd`)

| Monstre | Effectif | PV | Dégâts / attaque | Intervalle | Vitesse (cases/s) | Vision | Récompense (par individu) |
|---|---|---|---|---|---|---|---|
| Loup | 4 | 35 | 6 | 2,5 s | 3,5 | 6 | 4 Nourri, 1 O |
| Loup alpha | 1 | 70 | 10 | 2,5 s | 4 | 8 | 8 Nourri, 3 O |
| Ours | 1 | 200 | 20 | 4 s | 2 | 7 | 30 Nourri, 12 O |
| Golem | 1 | 350 | 20 (8 cases autour) | 5 s | 1 | 5 | 2 cristaux de mana |
| Slime | 2 | 65 | 8 | 3 s | 1,5 | 4 | 6 O |

Camps (16 sur la carte) : plus on s'approche du centre, plus c'est dangereux — golems au centre,
puis ours, meutes de loups (4 loups + 1 alpha), slimes aux abords.

**Comportement** : les monstres errent dans leur territoire ; ils attaquent dès qu'une unité entre dans
leur vision ; ils poursuivent jusqu'à la limite du territoire, puis rentrent et se soignent entièrement.
Les loups visent l'escouade la plus isolée (la plus petite). Le golem frappe le sol : 20 dégâts à chaque
unité des 8 cases adjacentes.

**Réapparition** (une fois le camp entièrement tué) : loups 3 tours, slimes 2, ours 5, golem 8.

**Récompense** : donnée au joueur qui porte le coup fatal (même par une brûlure). Cristaux de mana : nouvelle
ressource, pour les futurs bâtiments de mana.

## Mines (`scripts/world/mine_site.gd`)

- 5 mines (puits) : une au centre, 2 par côté. Sans PV, indestructibles, neutres au départ.
- **Capture** : plus aucune unité adverse ni monstre dans la zone, et rester un moment ; l'adversaire
  la reprend de la même façon ; des unités laissées sur place la gardent.
- **Exploitation** : choisir sa mine → onglet Construction → **Exploiter** (75 Gd, 5 Bs, 3 Ml) ;
  les ouvriers libres la construisent (2 tours). Une seule fois : pas de reconstruction après une reprise.
- **Production** : 5 métal + 1 lingot (10 Gd) par cycle, inépuisable ; consomme 3 Nourri par tour.
  Cycle : 20 s sans mineur, 15 / 12 / 10 s avec 1 / 2 / 3 **mineurs** (3 au plus). Mineurs choisis +
  clic sur sa mine exploitée : ils y travaillent.

Validés par l'auteur : capture 20 s dans une zone de 3 cases ; territoires slimes 4, loups 8, ours 5, golem 4.

## Valeurs PROVISOIRES

| Sujet | Valeur | Où |
|---|---|---|
| Pause entre deux promenades | 4 à 9 s | `MonsterCamp.WANDER_MIN / MAX` |
| Répartition des camps | quarts selon la distance au centre | `main.gd` |
