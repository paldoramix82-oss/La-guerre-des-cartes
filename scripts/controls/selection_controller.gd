class_name SelectionController
extends Node2D
## Sélection (clic / rectangle) et ordres (clic droit) pour l'équipe contrôlée.
##   Clic gauche        : sélectionner une escouade
##   Glisser gauche     : sélection rectangulaire
##   Maj + clic/glisser : ajouter à la sélection
##   Clic droit         : déplacer / attaquer l'escouade ennemie visée
##   Espace : stop · Échap : désélectionner · Tab : changer d'équipe contrôlée (test)

signal selection_changed(selected: Array[Squad])
signal controlled_team_changed(team: int)

const DRAG_THRESHOLD := 6.0

var map: GameMap
var controlled_team := 0
var selected: Array[Squad] = []

var _pressing := false
var _dragging := false
var _drag_start := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_drag_start = get_global_mouse_position()
			elif _pressing:
				_pressing = false
				_finish_selection(mb.shift_pressed)
				_dragging = false
				queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			issue_order_at(get_global_mouse_position())
	elif event is InputEventMouseMotion and _pressing:
		if get_global_mouse_position().distance_to(_drag_start) > DRAG_THRESHOLD:
			_dragging = true
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				set_controlled_team(1 - controlled_team)
			KEY_SPACE:
				for s in selected:
					s.order_stop()
			KEY_ESCAPE:
				set_selection([])


func set_controlled_team(team: int) -> void:
	controlled_team = team
	set_selection([])
	controlled_team_changed.emit(team)


func set_selection(squads: Array) -> void:
	for s in selected:
		if is_instance_valid(s):
			s.selected = false
	selected.clear()
	for s in squads:
		if is_instance_valid(s) and s.team == controlled_team and not (s in selected):
			selected.append(s)
			s.selected = true
			if not s.destroyed.is_connected(_on_squad_destroyed):
				s.destroyed.connect(_on_squad_destroyed)
	selection_changed.emit(selected)


func _finish_selection(additive: bool) -> void:
	var picked: Array = []
	if _dragging:
		var rect := Rect2(_drag_start, get_global_mouse_position() - _drag_start).abs()
		for s in _all_squads():
			if s.team == controlled_team and rect.has_point(s.global_position):
				picked.append(s)
	else:
		var s := squad_at(get_global_mouse_position())
		if s and s.team == controlled_team:
			picked.append(s)
	set_selection((selected + picked) if additive else picked)


func squad_at(world_pos: Vector2) -> Squad:
	var best: Squad = null
	var best_d := GameConfig.TILE_SIZE * 0.6
	for s in _all_squads():
		var d: float = s.global_position.distance_to(world_pos)
		if d < best_d:
			best = s
			best_d = d
	return best


func issue_order_at(world_pos: Vector2) -> void:
	if selected.is_empty():
		return
	var clicked := squad_at(world_pos)
	if clicked and clicked.team != controlled_team:
		for s in selected:
			s.order_attack(clicked)
		return
	# Déplacement de groupe : une case distincte par escouade autour du point visé.
	var center := map.world_to_cell(world_pos)
	var cells := map.spread_cells(center, selected.size())
	var ordered := selected.duplicate()
	var center_world := map.cell_to_world(center)
	ordered.sort_custom(func(a, b): return a.position.distance_squared_to(center_world) < b.position.distance_squared_to(center_world))
	for i in ordered.size():
		ordered[i].order_move(cells[i] if i < cells.size() else center)


func _on_squad_destroyed(squad: Squad) -> void:
	selected.erase(squad)
	selection_changed.emit(selected)


func _all_squads() -> Array:
	return get_tree().get_nodes_in_group(Squad.GROUP).filter(func(s): return s is Squad and s.is_alive())


func _draw() -> void:
	if _pressing and _dragging:
		var rect := Rect2(_drag_start, get_global_mouse_position() - _drag_start).abs()
		draw_rect(rect, Color(1, 1, 1, 0.12))
		draw_rect(rect, Color(1, 1, 1, 0.8), false, 1.0)
