class_name Hud
extends CanvasLayer
## Interface minimale du prototype : équipe contrôlée, aide et escouades sélectionnées.

const HELP := "Clic gauche : sélection · Glisser : rectangle · Maj : ajouter\n" \
	+ "Clic droit : déplacer / attaquer · Espace : stop · Échap : désélectionner\n" \
	+ "ZQSD/WASD/flèches : caméra · Molette : zoom · Tab : changer d'équipe (test)"

var _label: Label
var _selection: Array[Squad] = []
var _team := 0


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(_label)
	add_child(panel)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func on_selection_changed(selection: Array[Squad]) -> void:
	_selection = selection


func on_team_changed(team: int) -> void:
	_team = team


func _refresh() -> void:
	var lines := ["Équipe contrôlée : %s" % GameConfig.TEAM_NAMES[_team], HELP, ""]
	var valid := _selection.filter(func(s): return is_instance_valid(s) and s.is_alive())
	if valid.is_empty():
		lines.append("Aucune escouade sélectionnée")
	else:
		for s in valid:
			lines.append("%s  %d/%d individus  %d/%d PV  [%s]" % [
				s.data.display_name, s.alive_count(), s.data.squad_size,
				s.total_hp(), s.data.max_total_hp(), Squad.State.keys()[s.state]])
	_label.text = "\n".join(lines)
