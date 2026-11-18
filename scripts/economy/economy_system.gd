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
	_pay_squad_upkeep()
	for econ in economies:
		econ.end_turn()
	turn_processed.emit()


func _pay_squad_upkeep() -> void:
	if not is_inside_tree():
		return
	var squads := get_tree().get_nodes_in_group(Squad.GROUP).filter(
			func(s): return is_instance_valid(s) and s is Squad and s.is_alive())
	squads.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	for s in squads:
		var cost: Dictionary = s.data.upkeep_for(s.alive_count())
		s.set_fed(cost.is_empty() or economies[s.team].pay_upkeep(cost))


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
	return ""


## Paie et place le bâtiment. Retourne null si impossible.
func place_building(data: BuildingData, team: int, cell: Vector2i, parent: Node = null) -> Building:
	if placement_error(data, team, cell) != "":
		return null
	economies[team].pay(data.cost)
	var b := Building.new()
	b.completed.connect(_on_building_completed)
	b.recruited.connect(func(bb, u): squad_recruited.emit(bb, u))
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
	return ""


## Paie et ajoute `unit` à la file de la Caserne (choisie, sinon la moins occupée).
## Retourne la Caserne utilisée, ou null.
func recruit(unit: UnitData, team: int, barracks: Building = null) -> Building:
	if barracks == null:
		barracks = best_barracks(team, unit)
	if recruit_error(unit, team, barracks) != "":
		return null
	economies[team].pay(unit.cost)
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
	if b.data.workers > 0:
		workers_requested.emit(b, b.data.workers)


func _refresh_storage(team: int) -> void:
	var extra := {}
	for b in buildings:
		if is_instance_valid(b) and b.team == team and b.is_complete:
			for r in b.data.storage:
				extra[r] = extra.get(r, 0) + b.data.storage[r]
	economies[team].set_extra_storage(extra)


func buildings_of(team: int) -> Array:
	return buildings.filter(func(b): return is_instance_valid(b) and b.team == team)
