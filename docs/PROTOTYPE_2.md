# Prototype 2 — Ressources, ouvriers et constructions

Valeurs : `docs/VALEURS.md` (document de l'auteur « Le RTS » + réponses de l'auteur).

## Ce qui est implémenté

| Système | Fichier | Contenu |
|---|---|---|
| Ressources | `scripts/economy/resource_types.gd` | Or, Bois, Métal, Organique, Nourriture |
| Stock d'un joueur | `scripts/economy/player_economy.gd` | Quantités, capacités (base + bâtiments), paiement |
| Économie | `scripts/economy/economy_system.gd` | Tour : entretien puis production ; placement des bâtiments |
| Bâtiments | `scripts/world/building.gd`, `data/buildings/` | Chantier, construction par les ouvriers, nourri ou non |
| Gisements | `scripts/world/deposit.gd`, `data/deposits/` | Récolte sur place, épuisables |
| Emplacements | `scripts/world/deposit_layout.gd` | Gisements symétriques (royaumes + jungle) |
| Ouvriers | `data/units/worker.tres`, `Squad.order_work` | Récolter, construire |
| Interface | `scripts/ui/hud.gd`, `selection_controller.gd` | Barre de ressources, menu Construire, aperçu de pose |

## Règles appliquées (décisions de l'auteur)

- Départ : 1000 Gd, 50 Nourri, 10 O, 20 Bs, 10 Ml. Stockage de base : 2000 Gd, 50 Bs, 25 Ml, 25 O, 100 Nourri.
- Bank / Moulin / Entrepôt ajoutent leur capacité une fois terminés. Au-delà de la capacité, rien n'est stocké.
- Récolte **sur place** : un ouvrier à côté d'un gisement récolte 2 par tour. Le gisement s'épuise puis disparaît ;
  l'ouvrier passe alors au gisement du même type le plus proche.
- Il faut des ouvriers pour construire ; plus il y en a, plus c'est rapide (chaque ouvrier = 1 tour de travail par tour).
- Cabane Ouvrier : construite d'un coup, fournit 2 ouvriers, consomme 3 Nourri / tour. Pas de PV.
- Caserne : 4 tours de construction, pas de PV, indestructible (recrutement : Prototype 3).
- Chaque tour, un bâtiment terminé paie sa consommation, puis produit. **Sans nourriture**, il ne fonctionne pas :
  pas de production, et les ouvriers de sa cabane s'arrêtent (bâtiment grisé avec « ! »).
- On ne construit que dans son royaume, sur une case libre ; un bâtiment occupe une case et bloque le passage.

## Interface (maquette de l'auteur)

La maquette `assets/ui/mockup/interface_mockup.png` est découpée par `tools/extract_ui.py`
en éléments transparents (`assets/ui/hud/`) ; la résolution de base du jeu est celle de la
maquette (1672 × 941) et chaque élément est placé à ses coordonnées.

| Zone | Contenu | Script |
|---|---|---|
| Barre du haut | Or, Bois, Nourriture, Métal, Organique : quantité et revenu net du dernier tour ; nombre d'individus | `hud.gd` |
| Haut droite | Horloge de partie, Pause (menu), Accélérer (x2), Menu | `hud.gd` |
| Mini-carte | Terrain, gisements, bâtiments, unités, vue ; clic = déplacer la vue ; + / − / centrer | `minimap.gd` |
| Objectifs | Détruire le château ennemi, Vaincre le roi ennemi (Prototype 7) | `hud.gd` |
| Main de cartes | 3 emplacements vides (Prototype 5) | `hud.gd` |
| Portrait / Informations | Escouade choisie ; détails, ou aide ; description au survol d'une case | `hud.gd` |
| Onglets | Construction (bâtiments), Recrutement (unités et coûts, Prototype 3), Améliorations (à définir) | `build_panel.gd` |
| Commandes | Déplacer, Stop, Attaquer, Annuler, Tout choisir ; autres boutons « à définir » (grisés) | `command_panel.gd` |
| Menu pause | Reprendre, Quitter la partie, Retour au menu ; Paramètres et Statistiques à venir | `pause_menu.gd` |

Hors maquette (non définis) : la population « 48 / 70 » est remplacée par le nombre d'individus ;
le cristal bleu (probablement le mana) attend le Prototype 5.

## Commandes

- Menu **Construire** (en bas à gauche) → clic dans votre royaume pour poser (aperçu vert / rouge).
  Maj + clic : poser plusieurs fois. Échap ou clic droit : annuler.
- Ouvriers choisis au moment de la pose : ils vont construire. Sinon : ouvriers + clic sur le chantier.
- Ouvriers + clic sur un gisement : récolter.

## Valeurs PROVISOIRES (à fixer par l'auteur)

| Sujet | Valeur actuelle | Où |
|---|---|---|
| Quantité d'un gisement | 200 | `data/deposits/*.tres` |
| Récolte bois / nourriture / or | 2 par tour (valeur donnée pour le métal) | `GameConfig.WORKER_HARVEST_PER_TURN` |
| Ouvrier : PV, déplacement | 30 PV, 2 cases / tour | `data/units/worker.tres` |
| Emplacements des gisements | 5 par royaume, 7 par moitié de jungle | `scripts/world/deposit_layout.gd` |
| Taille d'un bâtiment | 1 case | `Building` |
| Ordre de paiement de l'entretien | Ordre de construction | `EconomySystem.process_turn` |

## Reporté

- **Mines** (Prototype 4, jungle) : sans PV, indestructibles, se capturent par siège et se reprennent ;
  produisent un peu d'or et de métal (quantités à définir).
- **Cabanes de garde** autour des bâtiments (colonne « Cabane Garde ») et défenses : avec les sièges (Prototype 7).
- **Consommation des unités militaires** : le principe est connu (sans nourriture, elles s'arrêtent), la quantité ne l'est pas.

## Questions ouvertes

1. Quantité de chaque gisement (et différente selon le type ?).
2. Récolte par tour pour le bois, la nourriture et l'or (2 comme le métal ?).
3. Organique : Ferme 2 / tour (fait) ; monstres / animaux de la forêt au Prototype 4.
4. PV et vitesse de l'ouvrier.
5. Consommation de nourriture des unités : fait (voir Prototype 3).
