class_name GameConfig
extends RefCounted
## Constantes globales du prototype.
##
## IMPORTANT : le GDD (§13) indique que plusieurs valeurs ne sont PAS encore définies
## (durées réelles, vitesse réelle des unités, dimensions de la carte...).
## Toutes les valeurs marquées [PROVISOIRE] ci-dessous sont des valeurs techniques
## temporaires permettant de rendre le prototype jouable. Elles doivent être
## validées ou remplacées par le game designer. Voir docs/PROTOTYPE_1.md.

## Taille d'une case en pixels (purement visuel, adaptée aux sprites 24 px).
const TILE_SIZE: int = 40

## [PROVISOIRE] Conversion "tour" -> secondes (GDD §1.2 : les valeurs en tours
## doivent être converties en secondes). Un déplacement de 1 = 1 case par tour.
const SECONDS_PER_TURN: float = 1.0

## [PROVISOIRE] Nombre de tours entre deux attaques d'une escouade.
const ATTACK_INTERVAL_TURNS: float = 1.0

## [PROVISOIRE] Dimensions de la carte, en cases (GDD §13 : "Carte : à définir").
const MAP_WIDTH: int = 60
const MAP_HEIGHT: int = 36

## [PROVISOIRE] Profondeur (en cases) de chaque royaume depuis le bord de la carte.
const KINGDOM_DEPTH: int = 14

## Fréquence de recalcul du chemin quand une escouade poursuit une cible (s).
const REPATH_INTERVAL: float = 0.5

## Couleurs des joueurs (index = équipe).
const TEAM_COLORS: Array = [Color(0.25, 0.55, 1.0), Color(1.0, 0.32, 0.25)]
const TEAM_NAMES: Array = ["Joueur 1", "Joueur 2"]

## Musiques (assets/music/). Choix d'ambiance modifiable librement.
const MUSIC_TITLE := "res://assets/music/campement.ogg"
const MUSIC_BATTLE := "res://assets/music/chevaliers_de_pik.ogg"


static func seconds_per_attack() -> float:
	return SECONDS_PER_TURN * ATTACK_INTERVAL_TURNS


## Convertit une vitesse en "cases par tour" (GDD) en pixels par seconde.
static func move_speed_px(cases_per_turn: float) -> float:
	return cases_per_turn * TILE_SIZE / SECONDS_PER_TURN
