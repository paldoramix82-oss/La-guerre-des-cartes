class_name Garrison
extends RefCounted
## Abri d'une Cabane Garde (décision de l'auteur) : on y place des unités ; quand un
## ennemi entre dans la vision de la cabane, elles sortent le combattre, puis rentrent
## quand plus aucun ennemi n'est en vue.
## [PROVISOIRE] Capacité : `garrison_capacity` individus (2) ; les gardes ne s'éloignent
## pas à plus de LEASH cases de la cabane.

const THINK_INTERVAL := 0.3
const LEASH := 3  ## cases au-delà de la vision

var building: Building
## Escouades affectées à la cabane (dedans, dehors en combat, ou en chemin).
var squads: Array[Squad] = []
var _think := 0.0


func _init(b: Building) -> void:
	building = b


func capacity() -> int:
	return building.data.garrison_capacity


func vision() -> int:
	return maxi(GameConfig.BUILDING_VISION, building.data.attack_range)


func count() -> int:
	var n := 0
	for s in squads:
		if is_instance_valid(s):
			n += s.alive_count()
	return n


func can_enter(s: Squad) -> bool:
	return s.team == building.team and not s.data.is_worker and s.garrison == null \
			and count() + s.alive_count() <= capacity()


## Envoie l'escouade dans la cabane (elle y entre en arrivant).
func send(s: Squad) -> bool:
	if not can_enter(s):
		return false
	squads.append(s)
	s.garrison = building
	_walk_home(s)
	return true


func is_inside(s: Squad) -> bool:
	return s.sheltered


## Fait sortir tout le monde définitivement (cabane détruite, ou bouton Annuler).
func release_all() -> void:
	for s in squads:
		if is_instance_valid(s):
			_go_out(s)
			s.garrison = null
	squads.clear()


func tick(delta: float) -> void:
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK_INTERVAL
	squads = squads.filter(func(s): return is_instance_valid(s) and s.is_alive())
	var threat := _nearest_threat(vision())
	for s in squads:
		if is_inside(s):
			if threat:
				_go_out(s)
				s.order_target(threat)
			continue
		var far := s.members.any(func(m): return building.distance_from(m.get_cell()) > vision() + LEASH)
		if threat and not far:
			if s.state != Squad.State.ACTING:
				s.order_target(threat)
		elif s.state != Squad.State.MOVING and _arrived(s):
			_go_in(s)
		elif s.state != Squad.State.MOVING:
			_walk_home(s)


func _nearest_threat(radius: int) -> Squad:
	var best: Squad = null
	var best_d := 1 << 30
	for n in building.get_tree().get_nodes_in_group(Individual.GROUP):
		var o := n as Individual
		if o == null or not o.is_alive() or o.team == building.team or o.squad.sheltered:
			continue
		var d := building.distance_from(o.get_cell())
		if d <= radius and d < best_d:
			best = o.squad
			best_d = d
	return best


func _arrived(s: Squad) -> bool:
	return s.members.all(func(m): return not m.is_moving() and building.distance_from(m.get_cell()) <= 1)


## Cases libres collées à la cabane, où l'escouade se place pour entrer.
func _door_cells(s: Squad) -> Array:
	var out: Array = []
	var map := building.map
	for oc in building.occupied_cells():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c: Vector2i = oc + Vector2i(dx, dy)
				if not (c in out) and building.distance_from(c) == 1 and map.is_free(c, null, s.members):
					out.append(c)
	out.sort_custom(func(a, b): return Vector2(a - s.get_cell()).length_squared() < Vector2(b - s.get_cell()).length_squared())
	return out.slice(0, s.alive_count())


func _walk_home(s: Squad) -> void:
	var cells := _door_cells(s)
	if cells.size() < s.alive_count():
		cells = building.map.spread_cells(building.cell, s.alive_count(), s.members)
	if not cells.is_empty():
		s.order_move_cells(cells)


func _go_in(s: Squad) -> void:
	s.order_stop()
	s.sheltered = true
	for m in s.members:
		m.visible = false


func _go_out(s: Squad) -> void:
	s.sheltered = false
	for m in s.members:
		m.visible = true
