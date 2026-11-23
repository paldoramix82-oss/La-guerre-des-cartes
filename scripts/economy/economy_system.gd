class_name EconomySystem
extends Node
## Économie des deux joueurs (GDD §3) :
## - un stock (PlayerEconomy) par joueur ;
## - placement des bâtiments (paiement, validité de la case) ;
## - à chaque tour : entretien puis production des bâtiments terminés ;
## - capacité de stockage = base + bâtiments de stockage terminés.
##
## Manque de nourriture (décision de l'auteur) : un bâtiment dont l'entretien ne
## peut pas être payé ne fonctionne pas pendant ce tour (pas de production ;
## pour une Cabane Ouvrier, ses ouvriers s'arrêtent).
## Les escouades paient aussi leur consommation (par individu, voir UnitData.upkeep) ;
## une escouade non nourrie s'arrête (ni déplacement, ni combat, ni travail).
## [PROVISOIRE] Ordre de paiement : bâtiments (ordre de construction), puis escouades
## (ordre de création).

const GROUP := &"economy_system"

signal building_placed(building: Building)
## Une Cabane Ouvrier terminée : la scène doit faire apparaître ses ouvriers.
signal workers_requested(building: Building, count: int)
signal turn_processed
## Une escouade recrutée doit apparaître à côté de sa Caserne.
signal squad_recruited(building: Building, unit: UnitData)

var map: GameMap
var economies: Array[PlayerEconomy] = []
var buildings: Array[Building] = []
var _turn_timer := 0.0


func _init() -> void:
	for team in 2:
		economies.append(PlayerEconomy.new(team))


func _enter_tree() -> void:
	add_to_group(GROUP)


func economy(team: int) -> PlayerEconomy:
	return economies[team]


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	for b in buildings:
		if is_instance_valid(b) and not b.queue.is_empty():
			b.tick_recruitment(delta)
	_turn_timer += delta
	while _turn_timer >= GameConfig.SECONDS_PER_TURN:
		_turn_timer -= GameConfig.SECONDS_PER_TURN
		process_turn()


## Un tour : chaque bâtiment terminé paie son entretien, puis produit s'il est nourri.
func process_turn() -> void:
	buildings = buildings.filter(func(b): return is_instance_valid(b))
	for b in buildings:
		if not b.is_complete:
			continue
		var econ := economies[b.team]
		var fed := b.data.upkeep.is_empty() or econ.pay_upkeep(b.data.upkeep)
		b.set_fed(fed)
		if fed and not b.data.production.is_empty():
			econ.add_all(b.data.production)
	_mine_production()
	_pay_squad_upkeep()
	for econ in economies:
		econ.end_turn()
	turn_processed.emit()


## Mines exploitées : consommation par tour (la production suit le cycle de la mine).
func _mine_production() -> void:
	if not is_inside_tree():
		return
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		if o is MineSite and o.is_producing():
			var econ := economies[o.team]
			o.fed = o.data.upkeep.is_empty() or econ.pay_upkeep(o.data.upkeep)
			o.queue_redraw()


## Lance l'exploitation d'une mine capturée : coût payé, les ouvriers la construisent.
func exploit_error(mine: MineSite, team: int) -> String:
	if mine.team != team:
		return "Capturez d'abord cette mine."
	if not mine.needs_exploitation():
		return "Mine déjà exploitée." if mine.exploited else "Exploitation déjà lancée."
	if not economies[team].can_afford(mine.data.cost):
		return "Ressources insuffisantes."
	return ""


func start_exploitation(mine: MineSite, team: int) -> bool:
	if exploit_error(mine, team) != "":
		return false
	economies[team].pay(mine.data.cost)
	mine.exploit_started = true
	mine.queue_redraw()
	return true


func _pay_squad_upkeep() -> void:
	if not is_inside_tree():
		return
	var squads := get_tree().get_nodes_in_group(Squad.GROUP).filter(
			func(s): return is_instance_valid(s) and s is Squad and s.is_alive())
	squads.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	# Escouades choisies avec « Nourrir » d'abord. En rationnement (nourriture sous
	# RATIONING_THRESHOLD de la capacité), seules elles sont servies.
	squads.sort_custom(func(a, b): return int(b.ration_priority) < int(a.ration_priority))
	var rationing := [false, false]
	for t in 2:
		var e := economies[t]
		rationing[t] = e.get_amount(ResourceTypes.FOOD) <= e.capacity(ResourceTypes.FOOD) * GameConfig.RATIONING_THRESHOLD
	for s in squads:
		if s.team < 0 or s.team > 1:
			continue  # monstres : pas d'économie
		var cost: Dictionary = s.data.upkeep_for(s.alive_count())
		if cost.is_empty():
			s.set_fed(true)
		elif rationing[s.team] and not s.ration_priority:
			s.set_fed(false)
		else:
			s.set_fed(economies[s.team].pay_upkeep(cost))


# --- Construction -------------------------------------------------------------

## Raison pour laquelle `data` ne peut pas être placé sur `cell` par `team` ("" si possible).
func placement_error(data: BuildingData, team: int, cell: Vector2i) -> String:
	if not data.player_buildable:
		return "Ce bâtiment ne se construit pas encore."
	if map.kingdom_of(cell) != team:
		return "Construisez dans votre royaume."
	if not map.is_free(cell):
		return "Case occupée."
	if not economies[team].can_afford(data.cost):
		return "Ressources insuffisantes."
	if economies[team].inhabitants < data.workers:
		return "Pas assez d'habitants."
	return ""


## Paie et place le bâtiment. Retourne null si impossible.
## `free` : bâtiment de départ (ni coût ni règle de placement).
func place_building(data: BuildingData, team: int, cell: Vector2i, parent: Node = null, free: bool = false) -> Building:
	if free:
		if not map.is_free(cell):
			return null
	elif placement_error(data, team, cell) != "":
		return null
	else:
		economies[team].pay(data.cost)
	if data.workers > 0:
		economies[team].take_inhabitants(data.workers)
	var b := Building.new()
	b.completed.connect(_on_building_completed)
	b.recruited.connect(func(bb, u): squad_recruited.emit(bb, u))
	b.destroyed.connect(_on_building_destroyed)
	(parent if parent else self).add_child(b)
	buildings.append(b)
	b.setup(data, team, map, cell)
	building_placed.emit(b)
	return b


# --- Recrutement (Prototype 3) -------------------------------------------------

## Raison pour laquelle `unit` ne peut pas être recruté par `team` ("" si possible).
func recruit_error(unit: UnitData, team: int, barracks: Building = null) -> String:
	if barracks == null:
		barracks = best_barracks(team, unit)
	if barracks == null:
		return "Construisez d'abord une Caserne."
	if not barracks.can_recruit(unit):
		return "Cette Caserne ne recrute pas cette unité."
	if not economies[team].can_afford(unit.cost):
		return "Ressources insuffisantes."
	if economies[team].inhabitants < unit.squad_size:
		return "Pas assez d'habitants (%d nécessaires)." % unit.squad_size
	if barracks.queued_individuals() + unit.squad_size > GameConfig.BARRACKS_CAPACITY:
		return "Caserne pleine (%d individus au plus)." % GameConfig.BARRACKS_CAPACITY
	return ""


## Annule le dernier recrutement en file : coût et habitants remboursés.
func cancel_recruit(barracks: Building) -> UnitData:
	if barracks == null or barracks.queue.is_empty():
		return null
	var unit: UnitData = barracks.queue.pop_back()
	if barracks.queue.is_empty():
		barracks.recruit_progress = 0.0
	economies[barracks.team].add_all(unit.cost)
	economies[barracks.team].give_inhabitants(unit.squad_size)
	barracks.queue_redraw()
	return unit


## Paie et ajoute `unit` à la file de la Caserne (choisie, sinon la moins occupée).
## Retourne la Caserne utilisée, ou null.
func recruit(unit: UnitData, team: int, barracks: Building = null) -> Building:
	if barracks == null:
		barracks = best_barracks(team, unit)
	if recruit_error(unit, team, barracks) != "":
		return null
	economies[team].pay(unit.cost)
	economies[team].take_inhabitants(unit.squad_size)
	barracks.queue.append(unit)
	barracks.queue_redraw()
	return barracks


func best_barracks(team: int, unit: UnitData) -> Building:
	var best: Building = null
	for b in buildings_of(team):
		if b.can_recruit(unit) and (best == null or b.queue.size() < best.queue.size()):
			best = b
	return best


func _on_building_completed(b: Building) -> void:
	_refresh_storage(b.team)
	if b.data.inhabitants > 0:
		economies[b.team].give_inhabitants(b.data.inhabitants)
	if b.data.workers > 0:
		workers_requested.emit(b, b.data.workers)


func _on_building_destroyed(b: Building) -> void:
	buildings.erase(b)
	_refresh_storage(b.team)


func _refresh_storage(team: int) -> void:
	var extra := {}
	for b in buildings:
		if is_instance_valid(b) and b.team == team and b.is_complete and b.is_alive():
			for r in b.data.storage:
				extra[r] = extra.get(r, 0) + b.data.storage[r]
	economies[team].set_extra_storage(extra)


func buildings_of(team: int) -> Array:
	return buildings.filter(func(b): return is_instance_valid(b) and b.team == team)


## La nourriture de `team` est-elle sous le seuil de rationnement ?
func is_rationing(team: int) -> bool:
	var e := economies[team]
	return e.get_amount(ResourceTypes.FOOD) <= e.capacity(ResourceTypes.FOOD) * GameConfig.RATIONING_THRESHOLD
