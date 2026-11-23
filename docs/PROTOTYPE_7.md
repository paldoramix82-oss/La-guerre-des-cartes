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
| Cabane Garde | 50 | (ses gardes) | vision 3 | abri pour 2 individus *, consomme 2 Nourri / tour | — |
| Mortier | 125 | 30 | 2 à 6 | zone de 2 cases alignées | 6 s |
| Barricade | 50 | — | — | bloque le passage, 2 cases de long | — |

\* provisoire.

- Construites comme les autres bâtiments (onglet Construction, page 2 avec les flèches), dans son royaume,
  par les ouvriers.
- Tir automatique sur l'ennemi le plus proche à portée (joueur adverse ou monstre) ; ne tire pas si la
  défense n'est pas nourrie. Une défense voit jusqu'à sa portée (brouillard).
- Défense choisie : sa portée est affichée.

### Cabane Garde (décision de l'auteur)
- On y **place des unités** : escouades choisies + clic sur la cabane (2 individus au plus *).
  Elles sont à l'abri (invisibles, intouchables).
- Quand un ennemi (joueur ou monstre) **entre dans sa vision**, les gardes sortent et l'attaquent ;
  quand plus aucun ennemi n'est en vue, ils rentrent. Ils ne s'éloignent pas à plus de 3 cases de sa vision.
- Cabane choisie + ⊘ : les gardes sortent pour de bon. Un ordre de déplacement libère aussi l'escouade.
- **Bank, Moulin, Entrepôt** viennent avec leurs cabanes : 5, 2 et 3 Cabanes Garde apparaissent autour
  d'eux une fois construits (en laissant l'accès au bâtiment).

## Questions ouvertes

Voir `docs/QUESTIONS.md`.
