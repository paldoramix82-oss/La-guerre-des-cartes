class_name Squad
extends Node2D
## Escouade : entité contrôlable unique composée de plusieurs individus (GDD §5).
## Chaque individu (Individual) occupe sa propre case ; l'escouade reçoit les ordres
## et les répartit entre ses individus. Les statistiques proviennent d'un UnitData.

signal members_changed(squad: Squad)
signal destroyed(squad: Squad)

## ACTING = attaque (ennemi) ou soin (allié) selon `data.action`.
## WORKING = ouvrier qui récolte un gisement ou construit un bâtiment.
enum State { IDLE, MOVING, ACTING, WORKING }

## Rayon (cases) dans lequel un ouvrier cherche un gisement du même type quand le sien est épuisé.
const NEXT_DEPOSIT_RADIUS := 10

const GROUP := &"squads"
## Fréquence de recherche automatique de cible quand l'escouade est inactive (s).
const AUTO_ACQUIRE_INTERVAL := 0.2

var data: UnitData
var team: int = 0
var map: GameMap
var members: Array[Individual] = []

var state: State = State.IDLE
var target: Squad = null
## Cible acquise automatiquement : pas de poursuite hors de portée.
var _auto_target := false
var _acquire_timer := 0.0
## Objet travaillé (gisement ou chantier).
var work_target: MapObject = null
## Type du dernier gisement récolté (pour enchaîner sur un gisement voisin).
var _last_deposit_type: StringName = &""
## Cabane d'origine des ouvriers : s'ils ne sont pas nourris, ils ne travaillent pas.
var home: Building = null

var selected := false:
	set(value):
		selected = value
		for m in members:
			if is_instance_valid(m):
				m.queue_redraw()


## Crée l'escouade et place ses individus autour de `cell`, une case chacun
## (ou exactement sur `cells` si fourni).
func setup(p_data: UnitData, p_team: int, p_map: GameMap, cell: Vector2i, cells: Array = []) -> Squad:
	data = p_data
	team = p_team
	map = p_map
	name = "%s_%d" % [data.id, get_instance_id()]
	if cells.is_empty():
		cells = map.spread_cells(cell, data.squad_size)
	for i in mini(data.squad_size, cells.size()):
		var m := Individual.new()
		m.squad = self
		m.hp = data.hp
		m.name = "%s_%d" % [data.id, i]
		add_child(m)
		m.place(cells[i])
		members.append(m)
	return self


func _enter_tree() -> void:
	add_to_group(GROUP)


# --- État -------------------------------------------------------------------

func alive_count() -> int:
	return members.size()


func is_alive() -> bool:
	return not members.is_empty()


func total_hp() -> int:
	var t := 0
	for m in members:
		t += m.hp
	return t


func max_total_hp() -> int:
	return data.max_total_hp()


func is_wounded() -> bool:
	return members.any(func(m): return m.is_wounded())


## Faux si l'entretien (nourriture) de la cabane de l'ouvrier n'a pas été payé.
func is_fed() -> bool:
	return not is_instance_valid(home) or home.fed


func is_burning() -> bool:
	return members.any(func(m): return m.is_burning())


## Centre de l'escouade (moyenne des positions des individus).
func center() -> Vector2:
	if members.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for m in members:
		sum += m.position
	return sum / members.size()


func get_cell() -> Vector2i:
	return map.world_to_cell(center())


func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for m in members:
		out.append(m.get_cell())
	return out


# --- Ordres -----------------------------------------------------------------

## Déplace l'escouade vers `cell` : chaque individu reçoit une case libre autour.
func order_move(cell: Vector2i) -> void:
	order_move_cells(map.spread_cells(cell, members.size(), members))


## Déplace les individus sur les cases données (attribution au plus proche).
func order_move_cells(dest_cells: Array) -> void:
	target = null
	work_target = null
	_auto_target = false
	var remaining := dest_cells.duplicate()
	for m in members:
		m.target = null
		if remaining.is_empty():
			m.stop()
			continue
		var best := 0
		for i in remaining.size():
			if m.position.distance_squared_to(map.cell_to_world(remaining[i])) \
					< m.position.distance_squared_to(map.cell_to_world(remaining[best])):
				best = i
		m.move_to(remaining[best])
		remaining.remove_at(best)
	state = State.MOVING if members.any(func(m): return m.is_moving()) else State.IDLE


## Attaque (ennemi) ou soigne (allié) l'escouade `other` selon l'action de l'unité.
## Retourne false si cette escouade ne peut pas agir sur `other`.
func order_target(other) -> bool:
	if not CombatSystem.can_target(self, other):
		return false
	target = other
	_auto_target = false
	state = State.ACTING
	return true


## Ouvriers : récolter le gisement / construire le chantier `obj`.
func order_work(obj) -> bool:
	if not is_instance_valid(obj) or not (obj is MapObject) or not obj.can_be_worked_by(self):
		return false
	target = null
	_auto_target = false
	work_target = obj
	if obj is Deposit:
		_last_deposit_type = obj.data.id
	for m in members:
		m.target = null
	state = State.WORKING
	return true


func order_stop() -> void:
	work_target = null
	target = null
	_auto_target = false
	for m in members:
		m.target = null
		if m.is_moving():
			m.stop()
	state = State.IDLE


# --- Simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)


## Avance la simulation de `delta` secondes (appelable directement par les tests).
func tick(delta: float) -> void:
	for m in members.duplicate():
		if is_instance_valid(m) and m.is_alive():
			m.tick(delta)
	if not is_alive():
		return
	match state:
		State.IDLE:
			_acquire_timer -= delta
			if _acquire_timer <= 0.0:
				_acquire_timer = AUTO_ACQUIRE_INTERVAL
				_auto_acquire()
		State.MOVING:
			if not members.any(func(m): return m.is_moving()):
				state = State.IDLE
		State.ACTING:
			_process_action(delta)
		State.WORKING:
			_process_work(delta)


func _process_action(delta: float) -> void:
	if not CombatSystem.can_target(self, target) \
			or (data.action == UnitData.ActionType.HEAL and not target.is_wounded()):
		order_stop()
		return
	var target_squad = target
	var any_in_range := false
	for m in members.duplicate():
		if is_instance_valid(m) and m.is_alive():
			if m.update_action(delta, target_squad, not _auto_target):
				any_in_range = true
	if _auto_target and not any_in_range:
		order_stop()


func _process_work(delta: float) -> void:
	if not is_instance_valid(work_target) or not work_target.can_be_worked_by(self):
		var was_deposit := _last_deposit_type != &"" and not is_instance_valid(work_target)
		order_stop()
		if was_deposit:
			_work_next_deposit()
		return
	var fed := is_fed()
	for m in members.duplicate():
		if is_instance_valid(m) and m.is_alive():
			m.update_work(delta, work_target, fed)


## Gisement épuisé : passe au gisement du même type le plus proche, s'il y en a un.
func _work_next_deposit() -> void:
	var best: Deposit = null
	var best_d := NEXT_DEPOSIT_RADIUS + 1
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		if o is Deposit and o.is_alive() and o.data.id == _last_deposit_type:
			var d := CombatSystem.grid_distance(get_cell(), o.cell)
			if d < best_d:
				best = o
				best_d = d
	if best:
		order_work(best)


## Escouade inactive : agit sur l'escouade dont un individu valide est à portée
## d'un de ses individus (ennemi pour l'attaque, allié blessé pour le soin), sans poursuite.
func _auto_acquire() -> void:
	if not is_inside_tree():
		return
	var best: Squad = null
	var best_d := 1 << 30
	for other in get_tree().get_nodes_in_group(Individual.GROUP):
		var o := other as Individual
		if o == null or not o.is_alive() or not CombatSystem.can_target(self, o.squad):
			continue
		if data.action == UnitData.ActionType.HEAL and not o.is_wounded():
			continue
		for m in members:
			var d := CombatSystem.grid_distance(m.get_cell(), o.get_cell())
			if d <= data.attack_range and d < best_d:
				best = o.squad
				best_d = d
	if best:
		order_target(best)
		_auto_target = true


func on_member_died(m: Individual) -> void:
	members.erase(m)
	members_changed.emit(self)
	if members.is_empty():
		destroyed.emit(self)
		queue_free()
