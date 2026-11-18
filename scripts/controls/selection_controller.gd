class_name SelectionController
extends Node2D
## Sélection et ordres pour l'équipe contrôlée, jouables avec un seul bouton
## (trackpad Mac) :
##   Clic sur une de vos escouades   : la sélectionner (Maj : ajouter / retirer)
##   Glisser sur le terrain          : sélection rectangulaire (Maj : ajouter)
##   Clic sur le terrain             : déplacer la sélection à cet endroit
##   Clic sur un ennemi              : l'attaquer
##   Option (Alt) + clic sur un allié : le soigner (Soigneur)
##   Clic droit / clic à deux doigts : ordre direct (déplacer / attaquer / soigner)
##   Cmd/Ctrl + A : tout sélectionner · Espace : stop · Échap : désélectionner
##   Tab : changer d'équipe contrôlée (test)

signal selection_changed(selected: Array[Squad])
signal controlled_team_changed(team: int)

## Distance (pixels écran) au-delà de laquelle un clic devient un glisser.
const DRAG_THRESHOLD_SCREEN := 10.0
const MARKER_DURATION := 0.6
const COLOR_MOVE := Color(0.45, 1.0, 0.45)
const COLOR_ATTACK := Color(1.0, 0.35, 0.3)
const COLOR_HEAL := Color(1.0, 0.95, 0.45)

var map: GameMap
var controlled_team := 0
var selected: Array[Squad] = []

var _pressing := false
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_end := Vector2.ZERO
var _drag_start_screen := Vector2.ZERO
var _marker_pos := Vector2.ZERO
var _marker_time := 0.0
var _marker_color := COLOR_MOVE


func _process(delta: float) -> void:
	if _marker_time > 0.0:
		_marker_time -= delta
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Position du clic dans le monde, tirée de l'événement lui-même.
	var world_pos := Vector2.ZERO
	if event is InputEventMouse:
		world_pos = (make_input_local(event) as InputEventMouse).position
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_drag_start = world_pos
				_drag_end = world_pos
				_drag_start_screen = mb.position
			elif _pressing:
				_pressing = false
				_drag_end = world_pos
				if _dragging:
					_box_select(mb.shift_pressed)
				else:
					_on_click(world_pos, mb.shift_pressed, mb.alt_pressed)
				_dragging = false
				queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			issue_order_at(world_pos)
	elif event is InputEventMouseMotion and _pressing:
		_drag_end = world_pos
		if event.position.distance_to(_drag_start_screen) > DRAG_THRESHOLD_SCREEN:
			_dragging = true
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				set_controlled_team(1 - controlled_team)
			KEY_SPACE:
				stop_selected()
			KEY_ESCAPE:
				set_selection([])
			KEY_A:
				if event.meta_pressed or event.ctrl_pressed:
					select_all()


## Clic simple (sans glisser) : sélection ou ordre selon ce qui est sous le curseur.
func _on_click(world_pos: Vector2, shift: bool, alt: bool) -> void:
	var clicked := squad_at(world_pos)
	if clicked and clicked.team == controlled_team and not alt:
		if shift:
			var new_sel := selected.duplicate()
			if clicked in new_sel:
				new_sel.erase(clicked)
			else:
				new_sel.append(clicked)
			set_selection(new_sel)
		else:
			set_selection([clicked])
		return
	# Terrain, ennemi, ou Option + clic sur un allié : ordre à la sélection.
	issue_order_at(world_pos)


# --- Actions publiques (aussi utilisées par les boutons du HUD) ---------------

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


func select_all() -> void:
	set_selection(_all_squads().filter(func(s): return s.team == controlled_team))


func stop_selected() -> void:
	for s in selected:
		if is_instance_valid(s):
			s.order_stop()


func toggle_team() -> void:
	set_controlled_team(1 - controlled_team)


func squad_at(world_pos: Vector2) -> Squad:
	var best: Squad = null
	var best_d := GameConfig.TILE_SIZE * 0.6
	for s in _all_squads():
		for m in s.members:
			var d: float = m.global_position.distance_to(world_pos)
			if d < best_d:
				best = s
				best_d = d
	return best


## Ordre à la sélection : attaque d'un ennemi / soin d'un allié s'il y a une escouade
## sous `world_pos` (pour celles qui le peuvent), sinon déplacement vers ce point.
func issue_order_at(world_pos: Vector2) -> void:
	if selected.is_empty():
		return
	var clicked := squad_at(world_pos)
	var movers: Array = []
	var acted := false
	for s in selected:
		if clicked == null or not s.order_target(clicked):
			movers.append(s)
		else:
			acted = true
	if acted:
		_show_marker(world_pos, COLOR_ATTACK if clicked.team != controlled_team else COLOR_HEAL)
	if movers.is_empty():
		return
	if not acted:
		_show_marker(world_pos, COLOR_MOVE)
	# Déplacement de groupe : une case libre par individu autour du point visé ;
	# les escouades les plus proches prennent les cases les plus centrales.
	var center := map.world_to_cell(world_pos)
	var center_world := map.cell_to_world(center)
	movers.sort_custom(func(a, b): return a.center().distance_squared_to(center_world) < b.center().distance_squared_to(center_world))
	var all_members: Array = []
	for s in movers:
		all_members.append_array(s.members)
	var cells := map.spread_cells(center, all_members.size(), all_members)
	var start := 0
	for s in movers:
		var n: int = s.alive_count()
		s.order_move_cells(cells.slice(start, start + n))
		start += n


# --- Interne -------------------------------------------------------------------

func _box_select(additive: bool) -> void:
	var rect := Rect2(_drag_start, _drag_end - _drag_start).abs()
	var picked: Array = []
	for s in _all_squads():
		if s.team == controlled_team and s.members.any(func(m): return rect.has_point(m.global_position)):
			picked.append(s)
	set_selection((selected + picked) if additive else picked)


func _show_marker(world_pos: Vector2, color: Color) -> void:
	_marker_pos = map.cell_to_world(map.world_to_cell(world_pos))
	_marker_color = color
	_marker_time = MARKER_DURATION
	queue_redraw()


func _on_squad_destroyed(squad: Squad) -> void:
	selected.erase(squad)
	selection_changed.emit(selected)


func _all_squads() -> Array:
	return get_tree().get_nodes_in_group(Squad.GROUP).filter(func(s): return s is Squad and s.is_alive())


func _draw() -> void:
	if _pressing and _dragging:
		var rect := Rect2(_drag_start, _drag_end - _drag_start).abs()
		draw_rect(rect, Color(1, 1, 1, 0.12))
		draw_rect(rect, Color(1, 1, 1, 0.8), false, 1.0)
	if _marker_time > 0.0:
		# Repère de l'ordre : un cercle qui se resserre sur la case visée.
		var k := _marker_time / MARKER_DURATION
		var r := GameConfig.TILE_SIZE * (0.25 + 0.35 * k)
		draw_arc(_marker_pos, r, 0, TAU, 24, Color(_marker_color, k), 2.0)
