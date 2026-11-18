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
## [PROVISOIRE] Ordre de paiement : bâtiments dans l'ordre de leur construction.

signal building_placed(building: Building)
## Une Cabane Ouvrier terminée : la scène doit faire apparaître ses ouvriers.
signal workers_requested(building: Building, count: int)
signal turn_processed

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
		var fed := b.data.upkeep.is_empty() or econ.pay(b.data.upkeep)
		b.set_fed(fed)
		if fed and not b.data.production.is_empty():
			econ.add_all(b.data.production)
	turn_processed.emit()


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
	(parent if parent else self).add_child(b)
	buildings.append(b)
	b.setup(data, team, map, cell)
	building_placed.emit(b)
	return b


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
