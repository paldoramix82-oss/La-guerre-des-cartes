# Prototype 7 — Défenses et sièges (en cours)

Château, roi et conditions de victoire : en attente des valeurs de l'auteur.

## Fait

### Bâtiments attaquables
- Les bâtiments **avec PV** peuvent être attaqués et détruits : escouade choisie + clic sur un bâtiment
  ennemi. Barre de PV sur le bâtiment endommagé.
- Sans PV (Cabane Ouvrier, Caserne, Maison, Mine) : **indestructibles** (décision de l'auteur).
- Un bâtiment détruit disparaît ; sa capacité de stockage disparaît avec lui.

### Défenses (valeurs du document « Le RTS »)

| Défense | PV | Dégâts | Portée | Particularité | Intervalle * |
|---|---|---|---|---|---|
| Tour Archer | 100 | 20 | 7 | consomme 2 Nourri / tour | 3 s |
| Canon | 150 | 40 | 4 | | 5 s |
| Cabane Garde | 50 | 2 x 10 | 3 | 2 gardes, consomme 2 Nourri / tour | 3 s |
| Mortier | 125 | 30 | 2 à 6 | zone de 2 cases alignées | 6 s |
| Barricade | 50 | — | — | bloque le passage (1 case *) | — |

\* provisoire.

- Construites comme les autres bâtiments (onglet Construction, page 2 avec les flèches), dans son royaume,
  par les ouvriers.
- Tir automatique sur l'ennemi le plus proche à portée (joueur adverse ou monstre) ; ne tire pas si la
  défense n'est pas nourrie. Une défense voit jusqu'à sa portée (brouillard).
- Défense choisie : sa portée est affichée.

## Questions ouvertes

Voir `docs/QUESTIONS.md`.
