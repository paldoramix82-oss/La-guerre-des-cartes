class_name CommandPanel
extends TextureRect
## Grille de 9 commandes de la maquette. Les commandes dont la mécanique n'est pas
## encore définie par l'auteur sont désactivées (bulle « à définir »).

signal command(name: StringName)

const COL_X := [22, 99, 178]
const ROW_Y := [23, 92, 161]
const BUTTON_SIZE := Vector2(67, 60)

## [nom de commande (vide = à définir), bulle d'aide] dans l'ordre de la maquette.
const COMMANDS := [
	[&"move", "Déplacer : cliquez ensuite sur la destination"],
	[&"", "Défendre — à définir"],
	[&"stop", "Stop (Espace)"],
	[&"attack", "Attaquer : cliquez ensuite sur un ennemi"],
	[&"", "À définir"],
	[&"", "À définir"],
	[&"cancel", "Annuler / désélectionner (Échap)"],
	[&"select_all", "Choisir toutes vos escouades (Cmd + A)"],
	[&"", "Point de ralliement — Prototype 3"],
]


func _ready() -> void:
	texture = UiUtil.tex("commands")
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in COMMANDS.size():
		var rect := Rect2(Vector2(COL_X[i % 3], ROW_Y[i / 3]), BUTTON_SIZE)
		var b := UiUtil.hotspot(self, rect, COMMANDS[i][1])
		var cmd: StringName = COMMANDS[i][0]
		b.disabled = cmd == &""
		if not b.disabled:
			b.pressed.connect(func(): command.emit(cmd))
