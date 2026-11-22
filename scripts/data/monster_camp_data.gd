class_name MonsterCampData
extends Resource
## Type de camp de monstres (zone de la jungle) : escouades, territoire, réapparition.

@export var id: StringName
@export var display_name: String = ""
## Escouades du camp (UnitData de data/monsters/).
@export var squads: Array = []
## Réapparition, en tours, une fois tout le camp tué (valeurs de l'auteur).
@export var respawn_turns: float = 3.0
## [PROVISOIRE] Rayon du territoire (cases) : les monstres y errent et poursuivent
## jusqu'à sa limite, puis rentrent et se soignent.
@export var territory_radius: int = 6
## Rang de danger : 0 = le plus faible (bords de la jungle), 3 = le plus fort (centre).
@export var danger: int = 0
