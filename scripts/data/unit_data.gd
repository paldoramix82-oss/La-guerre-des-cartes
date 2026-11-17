class_name UnitData
extends Resource
## Définition data-driven d'un type d'escouade (GDD §5.1).
## Une nouvelle unité s'ajoute en créant un fichier .tres dans res://data/units/,
## sans modifier le code.

## Géométrie de l'attaque (GDD §5.2).
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
## Portée en cases.
@export var attack_range: int = 1
@export var attack_pattern: AttackPattern = AttackPattern.SINGLE
## Taille de la zone (rayon pour CIRCLE, longueur pour LINE).
@export var zone_size: int = 1

@export_group("Déplacement")
## Déplacement en cases par tour (converti en secondes via GameConfig).
@export var move_speed: float = 1.0

@export_group("Présentation")
@export var color: Color = Color.WHITE
## Points du GDD non encore clarifiés pour cette unité.
@export_multiline var design_notes: String = ""


func max_total_hp() -> int:
	return squad_size * hp
