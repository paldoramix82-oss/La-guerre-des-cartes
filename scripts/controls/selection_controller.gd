class_name SelectionController
extends Node2D
## Sélection et ordres pour l'équipe contrôlée, jouables avec un seul bouton
## (trackpad Mac) :
##   Clic sur une de vos escouades   : la sélectionner (Maj : ajouter / retirer)
##   Glisser sur le terrain          : sélection rectangulaire (Maj : ajouter)
##   Clic sur le terrain             : déplacer la sélection à cet endroit
##   Clic sur un ennemi              : l'attaquer
##   Option (Alt) + clic sur un allié : le soigner (Soigneur)
##   Ouvriers + clic sur un gisement / un chantier : récolter / construire
##   Mode construction (menu Construire) : clic pour poser, Échap pour annuler
##   Clic droit / clic à deux doigts : ordre direct (déplacer / attaquer / soigner)
##   Cmd/Ctrl + A : tout sélectionner · Espace : stop · Échap : désélectionner
##   Tab : changer d'équipe contrôlée (test)

signal selection_changed(selected: Array[Squad])
signal controlled_team_changed(team: int)
signal build_mode_changed(data: BuildingData)
## Bâtiment choisi (clic sur l'un de vos bâtiments), ou null.
signal building_selected(building: Building)
## Message à afficher au joueur (ex. construction impossible).
signal notify(text: String)

## Distance (pixels écran) au-delà de laquelle un clic devient un glisser.
const DRAG_THRESHOLD_SCREEN := 10.0
const MARKER_DURATION := 0.6
const COLOR_MOVE := Color(0.45, 1.0, 0.45)
const COLOR_ATTACK := Color(1.0, 0.35, 0.3)
const COLOR_HEAL := Color(1.0, 0.95, 0.45)
const COLOR_WORK := Color(1.0, 0.8, 0.3)

var map: GameMap
var economy_system: EconomySystem
var selected_building: Building = null
## Ordre en attente d'un clic (boutons Déplacer / Attaquer du panneau de commandes).
enum OrderMode { NONE, MOVE, ATTACK }
var order_mode: OrderMode = OrderMode.NONE
## Bâtiment en cours de placement (mode construction), ou null.
var build_data: BuildingData = null
var _hover_world := Vector2.ZERO
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
		_hover_world = world_pos
		if build_data and event is InputEventMouseMotion:
			queue_redraw()
	if build_data and _handle_build_input(event, world_pos):
		return
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
				cancel()
			KEY_A:
				if event.meta_pressed or event.ctrl_pressed:
					select_all()


## Clic simple (sans glisser) : sélection ou ordre selon ce qui est sous le curseur.
func _on_click(world_pos: Vector2, shift: bool, alt: bool) -> void:
	if order_mode != OrderMode.NONE:
		_apply_order_mode(world_pos)
		return
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
	# Clic sur l'un de vos bâtiments : le choisir (sauf ouvriers envoyés sur un chantier).
	var obj := map.object_at(map.world_to_cell(world_pos))
	if obj is Building and obj.team == controlled_team and not alt:
		var helps_build: bool = not obj.is_complete and selected.any(func(s): return s.data.is_worker)
		if not helps_build:
			select_building(obj)
			return
	# Terrain, ennemi, gisement, chantier, ou Option + clic sur un allié : ordre à la sélection.
	issue_order_at(world_pos)


# --- Ordres en deux temps (boutons Déplacer / Attaquer) -----------------------------

func start_order_mode(mode: OrderMode) -> void:
	if selected.is_empty():
		notify.emit("Choisissez d'abord une escouade.")
		return
	order_mode = mode
	notify.emit("Cliquez sur la destination." if mode == OrderMode.MOVE else "Cliquez sur un ennemi à attaquer.")


func _apply_order_mode(world_pos: Vector2) -> void:
	var mode := order_mode
	order_mode = OrderMode.NONE
	if mode == OrderMode.MOVE:
		move_selected_to(world_pos)
		return
	var clicked := squad_at(world_pos)
	if clicked == null or clicked.team == controlled_team:
		notify.emit("Pas d'ennemi ici.")
		return
	issue_order_at(world_pos)


## Annuler : quitte le mode en cours, sinon désélectionne.
func cancel() -> void:
	if build_data:
		cancel_build()
	elif order_mode != OrderMode.NONE:
		order_mode = OrderMode.NONE
	else:
		set_selection([])


# --- Mode construction ---------------------------------------------------------

func start_build(data: BuildingData) -> void:
	build_data = data
	build_mode_changed.emit(data)
	queue_redraw()


func cancel_build() -> void:
	build_data = null
	build_mode_changed.emit(null)
	queue_redraw()


## Gère les clics en mode construction. Retourne true si l'événement est consommé.
func _handle_build_input(event: InputEvent, world_pos: Vector2) -> bool:
	if not (event is InputEventMouseButton and event.pressed):
		return false
	if event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_build()
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	try_place_building(map.world_to_cell(world_pos), event.shift_pressed)
	return true


## Pose le bâtiment en mode construction sur `cell` ; les ouvriers sélectionnés
## vont le construire. Maj : rester en mode construction.
func try_place_building(cell: Vector2i, keep_mode: bool = false) -> Building:
	var err := economy_system.placement_error(build_data, controlled_team, cell)
	if err != "":
		notify.emit(err)
		return null
	var b := economy_system.place_building(build_data, controlled_team, cell, map.get_parent())
	_show_marker(b.position, COLOR_WORK)
	if not b.is_complete:
		var workers := selected.filter(func(s): return s.data.is_worker)
		if workers.is_empty():
			notify.emit("Chantier posé : envoyez des ouvriers le construire.")
		for w in workers:
			w.order_work(b)
	if not keep_mode or not economy_system.economy(controlled_team).can_afford(build_data.cost):
		cancel_build()
	return b


# --- Actions publiques (aussi utilisées par les boutons du HUD) ---------------

func set_controlled_team(team: int) -> void:
	controlled_team = team
	set_selection([])
	controlled_team_changed.emit(team)


func select_building(b: Building) -> void:
	set_selection([])
	selected_building = b
	b.selected = true
	building_selected.emit(b)


func _clear_building() -> void:
	if is_instance_valid(selected_building):
		selected_building.selected = false
	if selected_building != null:
		selected_building = null
		building_selected.emit(null)


func set_selection(squads: Array) -> void:
	_clear_building()
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
	var obj := map.object_at(map.world_to_cell(world_pos))
	var movers: Array = []
	var acted := false
	for s in selected:
		if clicked != null and s.order_target(clicked):
			acted = true
		elif clicked == null and obj != null and s.order_work(obj):
			acted = true
		else:
			movers.append(s)
	if acted:
		if clicked == null:
			_show_marker(obj.position, COLOR_WORK)
		else:
			_show_marker(world_pos, COLOR_ATTACK if clicked.team != controlled_team else COLOR_HEAL)
	if movers.is_empty():
		return
	if not acted:
		_show_marker(world_pos, COLOR_MOVE)
	_move_group(movers, world_pos)


## Déplace toute la sélection vers `world_pos` (sans attaquer ni travailler).
func move_selected_to(world_pos: Vector2) -> void:
	if selected.is_empty():
		return
	_show_marker(world_pos, COLOR_MOVE)
	_move_group(selected.duplicate(), world_pos)


## Déplacement de groupe : une case libre par individu autour du point visé ;
## les escouades les plus proches prennent les cases les plus centrales.
func _move_group(movers: Array, world_pos: Vector2) -> void:
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
	if build_data:
		_draw_build_ghost()
	if _marker_time > 0.0:
		# Repère de l'ordre : un cercle qui se resserre sur la case visée.
		var k := _marker_time / MARKER_DURATION
		var r := GameConfig.TILE_SIZE * (0.25 + 0.35 * k)
		draw_arc(_marker_pos, r, 0, TAU, 24, Color(_marker_color, k), 2.0)


func _draw_build_ghost() -> void:
	var cell := map.world_to_cell(_hover_world)
	var ok := economy_system.placement_error(build_data, controlled_team, cell) == ""
	var center := map.cell_to_world(cell)
	var half := GameConfig.TILE_SIZE * 0.5
	var col := Color(0.4, 1, 0.4) if ok else Color(1, 0.35, 0.3)
	draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2), Color(col, 0.25))
	draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2), col, false, 2.0)
	if build_data.sprite:
		var tex := build_data.sprite
		var size := tex.get_size() * (2.0 if tex.get_size().x <= 16 else 1.0)
		draw_texture_rect(tex, Rect2(center + Vector2(-size.x * 0.5, half - size.y), size), false, Color(1, 1, 1, 0.6))
