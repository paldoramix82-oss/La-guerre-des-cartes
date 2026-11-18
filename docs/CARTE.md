# Carte et brouillard de guerre

Décisions de l'auteur : carte **immense** (parties d'une trentaine de minutes), lacs et rivières,
forêt géante pleine d'arbres, zones de monstres, mines (puits), brouillard de guerre.

## Génération (`scripts/map/map_generator.gd`)

- **161 × 97 cases** (≈ 7 fois l'ancienne carte). Graine fixe `GameConfig.MAP_SEED` : même carte à chaque partie.
- **Symétrique** (rotation de 180°) : les deux joueurs ont exactement la même carte.
- Royaumes dégagés aux deux extrémités (28 cases), quelques bosquets ; jungle au milieu.
- **Forêt dense** : les arbres sont infranchissables ; des chemins y sont creusés.
- **Rivière** sinueuse au centre (3 cases), 4 gués + un gué à la mine centrale ; un affluent de chaque côté,
  avec son gué ; **lacs** ; massifs rocheux.
- **Clairières** :
  - **mines** (puits) : une au centre (puits magique) + 2 par moitié ;
  - **16 camps de monstres** (os et feu de camp) ;
  - **repaires** du Dragon (nord, grotte et coffre) et de la Sorcière (sud, chaudron et autel),
    à égale distance des deux joueurs.
- **Gisements** : 5 près de chaque départ, ~30 par moitié de jungle (bois et baies en lisière de forêt,
  métal et or près des rochers).
- Tout élément est **relié au départ** par un chemin ; les poches inaccessibles sont boisées.

## Brouillard de guerre (`scripts/map/fog_of_war.gd`)

- Jamais exploré : **noir**. Exploré mais hors de vue : **assombri**, sans les unités ennemies.
  En vue : clair.
- **Vision d'une unité = déplacement + 2 cases** : Guerrier 3, Archer 4, Cavalier 6, Mage 3,
  Soigneur 4, Mineur 6, Ouvrier 4.
- Unités ennemies visibles seulement en vue ; bâtiments ennemis visibles une fois découverts.
- La mini-carte suit le brouillard. Tab (test) : le brouillard suit le joueur contrôlé.

## Valeurs PROVISOIRES

| Sujet | Valeur | Où |
|---|---|---|
| Vision d'un bâtiment terminé | 3 cases | `GameConfig.BUILDING_VISION` |
| Zone révélée autour du départ (futur château) | 9 cases | `GameConfig.BASE_VISION` |
| Taille de la carte, largeur des royaumes | 161 × 97, 28 | `GameConfig` |
| Densité forêt / lacs / rochers, nombre de camps | réglages du générateur | `MapGenerator` (constantes) |

## Questions ouvertes

1. Vision des bâtiments et du château ?
2. « Assiettes d'eau » : le pack ne contient pas de tuiles d'eau ; l'eau est habillée avec les nénuphars,
   roseaux et vagues. S'agit-il d'autres images à m'envoyer ?
3. Taille de carte : convient-elle, ou plus grande encore ?
