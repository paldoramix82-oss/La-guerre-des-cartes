# Prototype 3 — Recrutement et gestion des escouades

## Ce qui est implémenté

| Système | Fichier | Contenu |
|---|---|---|
| File de recrutement | `scripts/world/building.gd` | Une escouade à la fois par Caserne (GDD §5.3) |
| Recrutement | `scripts/economy/economy_system.gd` | Paiement du coût, choix de la Caserne, fin de recrutement |
| Apparition | `scripts/main.gd` | L'escouade apparaît à côté de sa Caserne (une case par individu) |
| Consommation des unités | `UnitData.upkeep`, `EconomySystem` | Payée chaque tour, par individu |
| Interface | `build_panel.gd`, `hud.gd`, `selection_controller.gd` | Clic sur un bâtiment, onglet Recrutement, file affichée |

## Règles appliquées

- **Coût** : le coût de création du document (ex. Guerrier 4 Nourri + 50 Gd) est payé au lancement du
  recrutement, pour **une escouade** (les 4 guerriers).
- **Durée** : effectif / cadence de la Caserne. Ex. 4 guerriers à 4 / tour = 1 tour ;
  1 mineur à 2 / tour = un demi-tour ; 1 mage à 1 / tour = 1 tour.
- **File** : une seule escouade recrutée à la fois par Caserne ; les autres attendent.
- **Consommation** (décision de l'auteur, par individu et par tour) : Guerrier 2, Archer 1, Soigneur 1,
  Mage 1, Cavalier 3, Mineur 2, Ouvrier 2 Nourri.
- **Sans nourriture** : l'escouade s'arrête (ni déplacement, ni combat, ni travail) et apparaît grisée ;
  elle repart dès que sa consommation est payée.
- **Ferme** : produit aussi 2 Organique par tour (décision de l'auteur).
- Les armées de test du lancement sont désactivées (`GameConfig.SPAWN_TEST_ARMIES`) : la partie
  commence sans unité ; on construit une Cabane Ouvrier, puis une Caserne.

## Commandes

- Clic sur votre Caserne : elle est choisie (cadre blanc), l'onglet **Recrutement** s'ouvre.
- Clic sur une unité de l'onglet : recrutement lancé (Caserne choisie, sinon la moins occupée).
- Survol d'une unité : coût, caractéristiques et consommation dans le panneau d'informations.

## Valeurs / choix PROVISOIRES

| Sujet | Choix actuel | Où |
|---|---|---|
| Coût par escouade ou par individu | Par escouade | `EconomySystem.recruit` |
| Taille de la file | Illimitée | `Building.queue` |
| Ordre de paiement de la nourriture | Bâtiments puis escouades (ordre de création) | `EconomySystem.process_turn` |
| Annulation d'un recrutement | Non disponible | — |

## Questions ouvertes

1. Le coût de création est-il **par escouade** (actuel) ou **par individu** ?
2. **Cabane Ouvrier + ouvriers** : la cabane consomme 3 Nourri / tour et chaque ouvrier 2 : une cabane
   coûte donc 7 Nourri / tour. Est-ce voulu, ou les 3 de la cabane remplacent-ils ceux des ouvriers ?
3. Point de ralliement (drapeau) et « gestion des escouades » (fusion, séparation…) : à définir.
