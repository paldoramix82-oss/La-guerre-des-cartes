class_name MonsterCamp
extends Node2D
## Camp de monstres neutres de la jungle (décisions de l'auteur) :
## - les monstres errent dans leur territoire ;
## - ils attaquent dès qu'une unité d'un joueur entre dans leur vision ;
## - ils poursuivent jusqu'à la limite du territoire, puis rentrent et se soignent ;
## - une fois tout le camp tué, il réapparaît après `respawn_turns` tours.
## Les loups visent de préférence les escouades isolées (les plus petites).

const GROUP := &"monster_camps"
const THINK_INTERVAL := 0.25
## [PROVISOIRE] Pause entre deux promenades (s).
const WANDER_MIN := 4.0
const WANDER_MAX := 9.0

enum Mode { CALM, FIGHT, RETURN }

var data: MonsterCampData
var map: GameMap
var center := Vector2i.ZERO
var squads: Array[Squad] = []
var mode: Mode = Mode.CALM
## Parent des escouades créées (par défaut : le parent du camp).
var squads_parent: Node
var rng := RandomNumberGenerator.new()
var _think := 0.0
var _wander := 0.0
var _respawn_timer := -1.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func setup(p_data: MonsterCampData, p_map: GameMap, p_center: Vector2i, parent: Node = null) -> MonsterCamp:
	data = p_data
	map = p_map
	center = p_center
	position = map.cell_to_world(center)
	squads_parent = parent if parent else get_parent()
	rng.seed = hash(center)
	_wander = rng.randf_range(WANDER_MIN, WANDER_MAX)
	spawn()
	return self


func spawn() -> void:
	squads.clear()
	mode = Mode.CALM
	for u in data.squads:
		var cells := map.spread_cells(center, u.squad_size)
		if cells.size() < u.squad_size:
			continue
		var s := Squad.new()
		squads_parent.add_child(s)
		s.setup(u, GameConfig.MONSTER_TEAM, map, cells[0], cells)
		squads.append(s)


func alive_squads() -> Array[Squad]:
	var out: Array[Squad] = []
	for s in squads:
		if is_instance_valid(s) and s.is_alive():
			out.append(s)
	return out


func is_cleared() -> bool:
	return alive_squads().is_empty()


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	var alive := alive_squads()
	if alive.is_empty():
		if _respawn_timer < 0.0:
			_respawn_timer = data.respawn_turns * GameConfig.SECONDS_PER_TURN
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_timer = -1.0
			spawn()
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK_INTERVAL
	match mode:
		Mode.CALM:
			var intruder := find_intruder(alive)
			if intruder:
				_engage(alive, intruder)
			else:
				_wander_step(alive, THINK_INTERVAL)
		Mode.FIGHT:
			if _outside_territory(alive):
				_go_home(alive)
				return
			var intruder := find_intruder(alive)
			if intruder == null:
				_go_home(alive)
				return
			for s in alive:
				if s.state != Squad.State.ACTING:
					s.order_target(intruder)
		Mode.RETURN:
			if alive.all(func(s): return not s.members.any(func(m): return m.is_moving())):
				_heal_all(alive)
				mode = Mode.CALM


## Escouade d'un joueur dans la vision d'un monstre du camp (et dans le territoire).
func find_intruder(alive: Array[Squad]) -> Squad:
	var isolated := alive.any(func(s): return s.data.prefers_isolated)
	var best: Squad = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var o := n as Individual
		if o == null or not o.is_alive() or o.team == GameConfig.MONSTER_TEAM or o.squad.sheltered:
			continue
		if CombatSystem.grid_distance(o.get_cell(), center) > data.territory_radius:
			continue
		var seen := false
		var dist := INF
		for s in alive:
			for m in s.members:
				var d := CombatSystem.grid_distance(m.get_cell(), o.get_cell())
				if d <= s.data.vision_range():
					seen = true
				dist = minf(dist, d)
		if not seen:
			continue
		# Loups : la plus petite escouade d'abord ; sinon la plus proche.
		var score := dist + (o.squad.alive_count() * 100.0 if isolated else 0.0)
		if score < best_score:
			best = o.squad
			best_score = score
	return best


func _engage(alive: Array[Squad], target: Squad) -> void:
	mode = Mode.FIGHT
	for s in alive:
		s.order_target(target)


func _outside_territory(alive: Array[Squad]) -> bool:
	for s in alive:
		for m in s.members:
			if CombatSystem.grid_distance(m.get_cell(), center) > data.territory_radius:
				return true
	return false


func _go_home(alive: Array[Squad]) -> void:
	mode = Mode.RETURN
	var all_members: Array = []
	for s in alive:
		all_members.append_array(s.members)
	var cells := map.spread_cells(center, all_members.size(), all_members)
	var start := 0
	for s in alive:
		var n := s.alive_count()
		s.order_move_cells(cells.slice(start, start + n))
		start += n


## De retour au camp : les monstres se soignent entièrement.
func _heal_all(alive: Array[Squad]) -> void:
	for s in alive:
		for m in s.members:
			m.burns.clear()
			if m.hp < m.data.hp:
				m.heal(m.data.hp - m.hp)


func _wander_step(alive: Array[Squad], dt: float) -> void:
	_wander -= dt
	if _wander > 0.0:
		return
	_wander = rng.randf_range(WANDER_MIN, WANDER_MAX)
	var r := maxi(1, data.territory_radius / 2)
	for s in alive:
		if s.state != Squad.State.IDLE:
			continue
		var target := center + Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
		s.order_move(target)
