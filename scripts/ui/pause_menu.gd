class_name PauseMenu
extends Control
## Menu pause de la maquette (logo + Reprendre / Paramètres / Statistiques /
## Quitter la partie / Retour au menu). Met le jeu en pause tant qu'il est ouvert.

const TITLE_SCENE := "res://scenes/title.tscn"
## Lignes des boutons dans l'image du menu (x, y, largeur, hauteur).
const ROWS := [
	[&"resume", Rect2(23, 18, 234, 48), "Reprendre la partie (Échap)"],
	[&"", Rect2(23, 76, 234, 47), "Paramètres — bientôt"],
	[&"", Rect2(23, 133, 234, 48), "Statistiques — bientôt"],
	[&"quit", Rect2(23, 191, 234, 47), "Quitter le jeu"],
	[&"title", Rect2(23, 247, 234, 48), "Retour à l'écran titre"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	UiUtil.panel(self, "logo", Vector2(631, 120), 0.5, 0.5)
	var menu := UiUtil.panel(self, "pause_menu", Vector2(695, 360), 0.5, 0.5)
	for row in ROWS:
		var b := UiUtil.hotspot(menu, row[1], row[2])
		var action: StringName = row[0]
		b.disabled = action == &""
		if not b.disabled:
			b.pressed.connect(_on_action.bind(action))
	visible = false


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _on_action(action: StringName) -> void:
	match action:
		&"resume":
			close()
		&"quit":
			get_tree().quit()
		&"title":
			get_tree().paused = false
			Engine.time_scale = 1.0
			get_tree().change_scene_to_file(TITLE_SCENE)
