class_name GameConfig
extends RefCounted
## Constantes globales du prototype.
##
## IMPORTANT : le GDD (§13) indique que plusieurs valeurs ne sont PAS encore définies
## (durées réelles, vitesse réelle des unités, dimensions de la carte...).
## Toutes les valeurs marquées [PROVISOIRE] ci-dessous sont des valeurs techniques
## temporaires permettant de rendre le prototype jouable. Elles doivent être
## validées ou remplacées par le game designer. Voir docs/PROTOTYPE_1.md.

## Taille d'une case en pixels (purement visuel ; un individu par case, sprites 24 px).
const TILE_SIZE: int = 32

## Durée d'un tour en secondes (décision de l'auteur : 20 s « pour le moment »).
## Production, construction, recrutement, consommation et mana sont exprimés en tours.
## Le combat (intervalles d'attaque, brûlure) et les déplacements sont en secondes.
const SECONDS_PER_TURN: float = 20.0

## Dimensions de la carte, en cases. L'auteur veut une carte immense (parties
## d'une trentaine de minutes). Nombres impairs : une case exacte au centre.
const MAP_WIDTH: int = 161
const MAP_HEIGHT: int = 97
## [PROVISOIRE] Largeur (en cases) de chaque royaume depuis le bord de la carte.
const KINGDOM_DEPTH: int = 28
## Graine de génération de la carte (même carte à chaque partie tant qu'elle ne change pas).
const MAP_SEED: int = 7031

## --- Brouillard de guerre (décision de l'auteur) ---
## Vision d'une unité = son déplacement + VISION_BONUS cases.
const VISION_BONUS: int = 2
## [PROVISOIRE] Vision d'un bâtiment terminé, en cases.
const BUILDING_VISION: int = 3
## [PROVISOIRE] Zone révélée autour du point de départ (emplacement du futur château).
const BASE_VISION: int = 9

## Fréquence de recalcul du chemin quand une escouade poursuit une cible (s).
const REPATH_INTERVAL: float = 0.5

## Couleurs des joueurs (index = équipe).
const TEAM_COLORS: Array = [Color(0.25, 0.55, 1.0), Color(1.0, 0.32, 0.25)]
const TEAM_NAMES: Array = ["Joueur 1", "Joueur 2"]

## --- Économie (valeurs données par l'auteur, voir docs/VALEURS.md) ---

## Ressources de départ de chaque joueur.
const STARTING_RESOURCES := {&"gold": 1000, &"food": 50, &"organic": 10, &"wood": 20, &"metal": 10}
## Stockage de base, sans Bank / Moulin / Entrepôt.
const BASE_STORAGE := {&"gold": 2000, &"wood": 50, &"metal": 25, &"organic": 25, &"food": 100}
## Récolte d'un ouvrier sur un gisement, par tour (2 pour le métal ; appliqué
## aux autres ressources en attendant leur valeur).
const WORKER_HARVEST_PER_TURN: int = 2

## --- Cartes et mana (GDD §4, §9) ---
## Limite normale de la main (GDD §9).
const HAND_LIMIT: int = 3
## [PROVISOIRE] Régénération naturelle de mana par tour (GDD §13 : à définir).
const MANA_REGEN_PER_TURN: float = 0.25
## [PROVISOIRE] Capacité maximale de mana.
const MANA_MAX: float = 10.0
## Composition du deck (GDD §9) : 10 bonus, 5 malus, 5 neutres.
const DECK_BONUS: int = 10
const DECK_MALUS: int = 5
const DECK_NEUTRAL: int = 5

## Outil de test : faire apparaître une armée de chaque côté au lancement.
## Désactivé : avec la consommation de nourriture, elle serait affamée en 2 tours ;
## les unités se recrutent maintenant à la Caserne.
const SPAWN_TEST_ARMIES := false

## Musiques (assets/music/). Choix d'ambiance modifiable librement.
const MUSIC_TITLE := "res://assets/music/campement.ogg"
const MUSIC_BATTLE := "res://assets/music/chevaliers_de_pik.ogg"


## Convertit une vitesse en cases par seconde en pixels par seconde.
static func move_speed_px(cases_per_second: float) -> float:
	return cases_per_second * TILE_SIZE
