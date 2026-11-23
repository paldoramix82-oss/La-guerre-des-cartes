class_name BuildingData
extends Resource
## Définition data-driven d'un bâtiment, d'une défense ou d'une machine de siège.
## Valeurs : document de l'auteur « Le RTS » (docs/sources/Le_RTS.pages), voir docs/VALEURS.md.
## Les quantités de ressources sont des Dictionary {ResourceTypes.X: quantité}.
## Les durées sont en tours (converties en secondes via GameConfig.SECONDS_PER_TURN).

enum Category {
	RESOURCE,   ## Stockage (Bank, Moulin, Entrepôt)
	PRODUCTION, ## Production (Culture, Ferme, Mine)
	DEFENSE,    ## Défenses (Tour Archer, Canon, Cabane Garde, Barricade, Mortier)
	SIEGE,      ## Machines de siège (Échelle, Canon de siège)
	MILITARY,   ## Bâtiments militaires (Caserne)
	HOUSING,    ## Logement des ouvriers (Cabane Ouvrier)
}

@export var id: StringName
@export var display_name: String = ""
@export var category: Category = Category.RESOURCE

@export_group("Caractéristiques")
## PV (pour un bâtiment à plusieurs occupants, PV de chacun : voir `occupants`).
@export var hp: int = 0
## Nombre d'occupants (ancien sens de « Cabane Garde : 2 x 50 PV / 2 x 10 dégâts »).
@export var occupants: int = 1
## Abri : nombre d'individus qu'on peut y placer (Cabane Garde). 0 = pas d'abri.
@export var garrison_capacity: int = 0

@export_group("Économie")
## Coût de construction.
@export var cost: Dictionary = {}
## Durée de construction en tours.
@export var build_turns: int = 0
## Capacité de stockage ajoutée.
@export var storage: Dictionary = {}
## Production par tour.
@export var production: Dictionary = {}
## Consommation par tour (entretien, GDD §3.2).
@export var upkeep: Dictionary = {}
## Colonne « Cabane Garde » du document (sens à préciser).
@export var guard_huts: int = 0
## Ouvriers fournis (Cabane Ouvrier : 1) ; chacun est pris parmi les habitants.
@export var workers: int = 0
## Habitants ajoutés au royaume une fois construit (Maison : 5).
@export var inhabitants: int = 0
## Cadence de recrutement de la Caserne : {id d'unité: individus par tour}.
@export var recruit_per_turn: Dictionary = {}

@export_group("Combat")
@export var damage: int = 0
## Portée maximale en cases.
@export var attack_range: int = 0
## Portée minimale en cases (Mortier : 2 à 6).
@export var min_range: int = 0
## Taille de zone (Mortier : 2 zone).
@export var zone_size: int = 0
## [PROVISOIRE] Temps entre deux tirs, en secondes (non défini par l'auteur).
@export var attack_interval: float = 3.0
## Projectile affiché à chaque tir.
@export var projectile: Texture2D
@export var projectile_color: Color = Color.WHITE
@export var projectile_angle: float = 0.0

@export_group("Siège")
## Nombre d'unités transportées / servant la machine.
@export var unit_capacity: int = 0
## Déplacement en cases par tour.
@export var move_speed: float = 0.0

@export_group("Emprise")
## Taille en cases (Barricade « 2 L » : 2 cases de long).
@export var footprint: Vector2i = Vector2i(1, 1)


## Cases occupées si la case principale est `cell`.
func footprint_cells(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			out.append(cell + Vector2i(x, y))
	return out

@export_group("Règles")
## Le bâtiment peut être détruit (Caserne, Cabane Ouvrier, Mine : non).
@export var destructible: bool = true
## Proposé dans le menu de construction du joueur.
@export var player_buildable: bool = false

@export_group("Présentation")
@export var sprite: Texture2D
## Valeurs inconnues ou à préciser.
@export_multiline var design_notes: String = ""
