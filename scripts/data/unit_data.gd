class_name UnitData
extends Resource
## Définition data-driven d'un type d'escouade (GDD §5.1).
## Une nouvelle unité s'ajoute en créant un fichier .tres dans res://data/units/,
## sans modifier le code.

## Géométrie de l'attaque (GDD §5.2).
## Action principale de l'escouade.
enum ActionType {
	ATTACK, ## Inflige des dégâts aux ennemis.
	HEAL,   ## Rend des PV aux alliés (Soigneur).
}

enum AttackPattern {
	SINGLE, ## Cible une seule escouade.
	CIRCLE, ## Toutes les cases dans un rayon `zone_size` autour de l'attaquant (Cavalier : "Cercle 1").
	LINE,   ## `zone_size` cases alignées (horizontal ou vertical) à partir de la cible (Mage : "Zone 2").
}

@export var id: StringName
@export var display_name: String = ""
## Lettre affichée sur les individus (lisibilité du prototype).
@export var short_label: String = "?"

@export_group("Escouade")
## Nombre d'individus dans l'escouade ("Effectif").
@export var squad_size: int = 1
## PV de CHAQUE individu.
@export var hp: int = 1
## Dégâts de CHAQUE individu par attaque.
@export var damage: int = 0

@export_group("Combat")
@export var action: ActionType = ActionType.ATTACK
## PV rendus par CHAQUE individu à chaque soin (action HEAL).
@export var heal_amount: int = 0
## Brûlure appliquée aux escouades touchées : `burn_damage` dégâts par tour
## pendant `burn_turns` tours (Mage : 2 dégâts pendant 2 tours).
@export var burn_damage: int = 0
@export var burn_turns: int = 0
## Portée en cases.
@export var attack_range: int = 1
@export var attack_pattern: AttackPattern = AttackPattern.SINGLE
## Taille de la zone (rayon pour CIRCLE, longueur pour LINE).
@export var zone_size: int = 1

@export_group("Recrutement")
## Coût de création de l'escouade, ex. {&"food": 4, &"gold": 50} (voir ResourceTypes).
@export var cost: Dictionary = {}
## Consommation par tour de CHAQUE individu, ex. {&"food": 2}. Sans nourriture, l'escouade s'arrête.
@export var upkeep: Dictionary = {}


## Consommation par tour de `alive` individus.
func upkeep_for(alive: int) -> Dictionary:
	var out := {}
	for r in upkeep:
		out[r] = upkeep[r] * alive
	return out

@export_group("Déplacement")
## Déplacement en cases par tour (converti en secondes via GameConfig).
@export var move_speed: float = 1.0

@export_group("Capacités")
## Ouvrier : récolte les gisements et construit les bâtiments (GDD §3.3).
@export var is_worker: bool = false
## L'unité peut miner (Mineur). Le minage sera branché au Prototype 2 (ressources).
@export var can_mine: bool = false

@export_group("Présentation")
## Sprite d'un individu (assets/sprites/units/).
@export var sprite: Texture2D
@export var color: Color = Color.WHITE
## Points du GDD non encore clarifiés pour cette unité.
@export_multiline var design_notes: String = ""


func max_total_hp() -> int:
	return squad_size * hp
