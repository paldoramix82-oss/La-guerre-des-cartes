class_name GameMap
extends Node2D
## Grille de la carte : terrain, conversions case <-> monde et pathfinding (GDD §2).
## Le rendu est délégué à MapRenderer.
##
## La disposition actuelle est un PLACEHOLDER [PROVISOIRE] : le GDD (§13) laisse
## dimensions, génération et obstacles à définir. Elle reprend seulement la
## structure décrite : deux royaumes, une jungle neutre, une rivière.

enum Terrain { KINGDOM, JUNGLE, WATER, FORD, ROCK }

const BLOCKING_TERRAIN := [Terrain.WATER, Terrain.ROCK]

var width: int = GameConfig.MAP_WIDTH
var height: int = GameConfig.MAP_HEIGHT
var tiles := PackedInt32Array()
var astar := AStarGrid2D.new()


var renderer: MapRenderer


func _ready() -> void:
	if tiles.is_empty():
		generate_placeholder_layout()
	renderer = MapRenderer.new()
	renderer.map = self
	add_child(renderer)


# --- Génération -------------------------------------------------------------

func generate_placeholder_layout() -> void:
	tiles.resize(width * height)
	for y in height:
		for x in width:
			var in_kingdom := x < GameConfig.KINGDOM_DEPTH or x >= width - GameConfig.KINGDOM_DEPTH
			_set_tile(Vector2i(x, y), Terrain.KINGDOM if in_kingdom else Terrain.JUNGLE)

	# Rivière verticale au centre (2 cases de large), avec trois gués symétriques.
	var river_x := [width / 2 - 1, width / 2]
	var ford_rows := [5, 6, height / 2 - 1, height / 2, height - 7, height - 6]
	for y in height:
		for x in river_x:
			_set_tile(Vector2i(x, y), Terrain.FORD if y in ford_rows else Terrain.WATER)

	# Quelques massifs rocheux dans la jungle, symétriques par rotation de 180°
	# pour que les deux royaumes aient la même carte.
	var rocks := [
		Rect2i(18, 3, 3, 2), Rect2i(17, 12, 2, 4), Rect2i(22, 20, 3, 2),
		Rect2i(19, 27, 2, 3), Rect2i(25, 9, 2, 2),
	]
	for r in rocks:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_set_tile(Vector2i(x, y), Terrain.ROCK)
				_set_tile(Vector2i(width - 1 - x, height - 1 - y), Terrain.ROCK)

	_rebuild_navigation()
	if renderer:
		renderer.queue_redraw()


func _set_tile(cell: Vector2i, terrain: int) -> void:
	tiles[cell.y * width + cell.x] = terrain


func _rebuild_navigation() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, get_terrain(cell) in BLOCKING_TERRAIN)


# --- Requêtes ---------------------------------------------------------------

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func get_terrain(cell: Vector2i) -> int:
	return tiles[cell.y * width + cell.x]


func is_walkable(cell: Vector2i) -> bool:
	return is_inside(cell) and not (get_terrain(cell) in BLOCKING_TERRAIN)


func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * GameConfig.TILE_SIZE


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / GameConfig.TILE_SIZE).floor())


func world_size() -> Vector2:
	return Vector2(width, height) * GameConfig.TILE_SIZE


## Case praticable la plus proche (recherche en anneaux), ou `cell` elle-même.
func nearest_walkable(cell: Vector2i, max_radius: int = 10) -> Vector2i:
	cell = cell.clamp(Vector2i.ZERO, Vector2i(width - 1, height - 1))
	if is_walkable(cell):
		return cell
	for r in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if is_walkable(c):
					var d := Vector2(dx, dy).length_squared()
					if d < best_d:
						best_d = d
						best = c
		if best_d < INF:
			return best
	return cell


## Chemin de cases de `from` à `to` (exclut la case de départ).
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	from = nearest_walkable(from)
	to = nearest_walkable(to)
	if from == to:
		return result
	var ids := astar.get_id_path(from, to)
	for i in range(1, ids.size()):
		result.append(ids[i])
	return result


# --- Occupation : un individu par case ---------------------------------------
## Chaque individu réserve la case où il se trouve (ou vers laquelle il se rend).
## [PROVISOIRE] Les individus en mouvement peuvent traverser des cases occupées ;
## seules les cases d'arrêt sont exclusives.

var _occupants: Dictionary = {}


func reserve(cell: Vector2i, who: Object) -> void:
	_occupants[cell] = who


func release(cell: Vector2i, who: Object) -> void:
	if _occupants.get(cell) == who:
		_occupants.erase(cell)


func occupant(cell: Vector2i) -> Object:
	var o = _occupants.get(cell)
	if o != null and not is_instance_valid(o):
		_occupants.erase(cell)
		return null
	return o


## Case praticable et libre (ou réservée par `who` lui-même / par un objet de `ignore`).
func is_free(cell: Vector2i, who: Object = null, ignore: Array = []) -> bool:
	if not is_walkable(cell):
		return false
	var o := occupant(cell)
	return o == null or o == who or o in ignore


## `count` cases libres autour de `center`, de la plus proche à la plus lointaine.
func spread_cells(center: Vector2i, count: int, ignore: Array = []) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	center = nearest_walkable(center)
	var r := 0
	while result.size() < count and r <= 15:
		# Anneau r, trié par distance réelle : formation compacte (orthogonales d'abord).
		var ring: Array[Vector2i] = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r:
					ring.append(Vector2i(dx, dy))
		ring.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
		for off in ring:
			var c := center + off
			if is_free(c, null, ignore) and not (c in result):
				result.append(c)
				if result.size() >= count:
					return result
		r += 1
	return result


## Case libre à portée `rng` de `target_cell`, la plus proche de `from_cell`.
## Retourne Vector2i(-1, -1) si aucune.
func free_cell_in_range(target_cell: Vector2i, rng: int, from_cell: Vector2i, who: Object) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-rng, rng + 1):
		for dx in range(-rng, rng + 1):
			var c := target_cell + Vector2i(dx, dy)
			if c == target_cell or not is_free(c, who):
				continue
			var d := Vector2(c - from_cell).length_squared()
			if d < best_d:
				best_d = d
				best = c
	return best
