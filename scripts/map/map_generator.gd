class_name MapGenerator
extends RefCounted
## Génère la grande carte de jeu (décision de l'auteur : carte immense, forêt
## géante, lacs, rivières, zones de monstres, mines) :
## - deux royaumes dégagés aux extrémités, une jungle entre les deux ;
## - une forêt dense (cases d'arbres infranchissables) traversée de chemins ;
## - une rivière sinueuse au centre, avec gués, et des affluents ;
## - des lacs et des massifs rocheux ;
## - des clairières : mines (dont la mine centrale), camps de monstres, repaires du
##   Dragon et de la Sorcière (monstres : Prototype 4) ;
## - des gisements (arbres, baies) dans les royaumes et la jungle ; l'or et le
##   métal viennent des mines.
## Seule la moitié gauche est générée ; la droite en est le reflet par rotation de
## 180°, pour que les deux joueurs aient exactement la même carte.
## Les chemins relient le départ de chaque joueur à tous les éléments : tout est accessible.
## Les proportions ci-dessous sont des réglages de génération [PROVISOIRES].

const T := GameMap.Terrain

const FOREST_THRESHOLD := -0.24       ## plus bas = plus de forêt (jungle)
const KINGDOM_FOREST_THRESHOLD := 0.42 ## bosquets dans les royaumes
const ROCK_THRESHOLD := 0.58
const LAKE_THRESHOLD := 0.5
const BASE_CLEARING := 10
const CAMP_COUNT := 8         ## camps de monstres par moitié
const CAMP_SPACING := 14
const RIVER_WIDTH := 1        ## demi-largeur (3 cases)
const FORD_OFFSETS := [14, 31]  ## gués de la rivière, de part et d'autre du centre

## Gisements par moitié : [type, nombre dans le royaume, nombre dans la jungle].
const DEPOSITS := [
	[&"forest", 6, 26],
	[&"berries", 2, 8],
]


static func generate(map: GameMap, seed: int) -> void:
	var g := MapGenerator.new()
	g._run(map, seed)


var map: GameMap
var w: int
var h: int
var cx: int
var cy: int
var rng := RandomNumberGenerator.new()
var _carver: AStarGrid2D


func _run(p_map: GameMap, seed: int) -> void:
	map = p_map
	map.width = GameConfig.MAP_WIDTH
	map.height = GameConfig.MAP_HEIGHT
	map.kingdom_depth = GameConfig.KINGDOM_DEPTH
	w = map.width
	h = map.height
	cx = w / 2
	cy = h / 2
	rng.seed = seed
	map.tiles.resize(w * h)
	var base := Vector2i(map.kingdom_depth / 2, cy)

	_noise_terrain(seed, base)
	_rivers()
	var mines: Array = [Vector2i(map.kingdom_depth + 18, cy - 27), Vector2i(map.kingdom_depth + 22, cy + 24)]
	var dragon := Vector2i(cx, 9)
	_clearing(base, BASE_CLEARING, true)
	_clearing(Vector2i(cx, cy), 4, false)  # mine centrale, sur la rivière (gué)
	_clearing(dragon, 6, false)
	for m in mines:
		_clearing(m, 3, false)
	var avoid: Array = [base, Vector2i(cx, cy), dragon] + mines
	var camps := _place_camps(avoid)
	var deposits := _place_deposits(base, avoid + camps)
	_mirror()

	# Éléments des deux moitiés.
	var all_mines: Array = [Vector2i(cx, cy)]
	for m in mines:
		all_mines.append_array([m, _mirror_cell(m)])
	var all_camps: Array = []
	for c in camps:
		all_camps.append_array([c, _mirror_cell(c)])
	var all_deposits: Array = []
	for d in deposits:
		all_deposits.append([d[0], d[1]])
		all_deposits.append([d[0], _mirror_cell(d[1])])
	map.features = {
		&"bases": [base, _mirror_cell(base)],
		&"mines": all_mines,
		&"camps": all_camps,
		&"lairs": {&"dragon": dragon, &"witch": _mirror_cell(dragon)},
		&"deposits": all_deposits,
	}

	# Chemins : du départ vers chaque élément (et leur reflet), puis d'un départ à l'autre.
	var targets: Array = [Vector2i(cx, cy), dragon, _mirror_cell(base)] + mines + camps
	for d in deposits:
		targets.append(d[1])
	for t in targets:
		_carve_path(base, t)
	_remove_unreachable(base)
	map.finish_generation()


# --- Étapes ------------------------------------------------------------------

## Case canonique (moitié gauche + moitié haute de la colonne centrale).
func _is_canonical(c: Vector2i) -> bool:
	return c.x < cx or (c.x == cx and c.y <= cy)


func _mirror_cell(c: Vector2i) -> Vector2i:
	return Vector2i(w - 1 - c.x, h - 1 - c.y)


func _put(c: Vector2i, t: int) -> void:
	if map.is_inside(c) and _is_canonical(c):
		map.set_tile(c, t)


func _floor(c: Vector2i) -> int:
	return T.KINGDOM if map.kingdom_of(c) == 0 or map.kingdom_of(c) == 1 else T.JUNGLE


func _noise_terrain(seed: int, base: Vector2i) -> void:
	var forest := _noise(seed, 0.075, 3)
	var rock := _noise(seed + 1, 0.11, 2)
	var lake := _noise(seed + 2, 0.03, 2)
	for y in h:
		for x in cx + 1:
			var c := Vector2i(x, y)
			if not _is_canonical(c):
				continue
			var t := _floor(c)
			var f := forest.get_noise_2d(x, y)
			if t == T.KINGDOM:
				if f > KINGDOM_FOREST_THRESHOLD and c.distance_to(base) > BASE_CLEARING:
					t = T.FOREST
			elif lake.get_noise_2d(x, y) > LAKE_THRESHOLD and x > map.kingdom_depth + 6:
				t = T.WATER
			elif rock.get_noise_2d(x, y) > ROCK_THRESHOLD:
				t = T.ROCK
			elif f > FOREST_THRESHOLD:
				t = T.FOREST
			map.set_tile(c, t)


func _noise(seed: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Abscisse du centre de la rivière à la ligne `y` (fonction impaire autour du
## centre : la rivière est symétrique).
func _river_x(y: int) -> int:
	var u := float(y - cy)
	return cx + int(round(6.0 * sin(u * 0.055) + 2.5 * sin(u * 0.17)))


func _rivers() -> void:
	# Rivière principale.
	for y in h:
		var rx := _river_x(y)
		for x in range(rx - RIVER_WIDTH, rx + RIVER_WIDTH + 1):
			_put(Vector2i(x, y), T.WATER)
	# Gués (3 lignes chacun), symétriques.
	for off in FORD_OFFSETS:
		for sign in [-1, 1]:
			for dy in range(-1, 2):
				var y: int = cy + sign * off + dy
				var rx := _river_x(y)
				for x in range(rx - RIVER_WIDTH, rx + RIVER_WIDTH + 1):
					_put(Vector2i(x, y), T.FORD)
	# Affluent : de la rivière vers l'ouest, avec un gué.
	var y0 := cy - 21
	var x_end := map.kingdom_depth + 6
	for x in range(x_end, _river_x(y0)):
		var y := y0 + int(round(3.0 * sin(x * 0.13)))
		for dy in 2:
			var c := Vector2i(x, y + dy)
			var ford: bool = absi(x - (map.kingdom_depth + 22)) <= 1
			_put(c, T.FORD if ford else T.WATER)


## Clairière ronde ; `keep_water` : l'eau devient un gué au lieu d'être asséchée.
func _clearing(center: Vector2i, radius: int, keep_water: bool) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dy)
			if not map.is_inside(c) or Vector2(dx, dy).length() > radius + 0.3:
				continue
			var t: int = map.get_terrain(c)
			if t == T.WATER or t == T.FORD:
				_put(c, T.FORD if not keep_water else t)
			else:
				_put(c, _floor(c))


func _place_camps(avoid: Array) -> Array:
	var camps: Array = []
	var tries := 0
	while camps.size() < CAMP_COUNT and tries < 2000:
		tries += 1
		var c := Vector2i(rng.randi_range(map.kingdom_depth + 8, cx - 6), rng.randi_range(6, h - 7))
		if _too_close(c, avoid + camps, CAMP_SPACING):
			continue
		camps.append(c)
		_clearing(c, 3, false)
	return camps


func _too_close(c: Vector2i, others: Array, dist: float) -> bool:
	for o in others:
		if c.distance_to(o) < dist:
			return true
	return false


func _place_deposits(base: Vector2i, avoid: Array) -> Array:
	var out: Array = []
	var taken: Array = []
	for spec in DEPOSITS:
		var id: StringName = spec[0]
		# Dans le royaume : autour du point de départ.
		for i in spec[1]:
			var c := _find_cell(func(): return base + Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8)),
					func(cc): return cc.distance_to(base) >= 5 and map.kingdom_of(cc) == 0, taken + [base])
			if c != Vector2i(-1, -1):
				out.append([id, c])
				taken.append(c)
		# Dans la jungle : de préférence en lisière de forêt (bois, baies) ou près des rochers (minerais).
		for i in spec[2]:
			var want := T.FOREST
			var c := _find_cell(func(): return Vector2i(rng.randi_range(map.kingdom_depth + 3, cx - 4), rng.randi_range(3, h - 4)),
					func(cc): return _touches(cc, want) or rng.randf() < 0.15, taken + avoid)
			if c != Vector2i(-1, -1):
				out.append([id, c])
				taken.append(c)
	return out


## Case praticable tirée par `pick`, validée par `ok`, loin des cases `avoid`.
func _find_cell(pick: Callable, ok: Callable, avoid: Array) -> Vector2i:
	for i in 400:
		var c: Vector2i = pick.call()
		if not map.is_inside(c) or not _is_canonical(c):
			continue
		var t: int = map.get_terrain(c)
		if t != T.KINGDOM and t != T.JUNGLE:
			continue
		if _too_close(c, avoid, 3.0) or not ok.call(c):
			continue
		return c
	return Vector2i(-1, -1)


func _touches(c: Vector2i, terrain: int) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = c + d
		if map.is_inside(n) and map.get_terrain(n) == terrain:
			return true
	return false


func _mirror() -> void:
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not _is_canonical(c):
				map.set_tile(c, map.get_terrain(_mirror_cell(c)))


## Creuse un chemin de `from` à `to` à travers forêt / rochers / eau (l'eau devient un gué),
## et son reflet. Les chemins existants et les gués sont préférés.
func _carve_path(from: Vector2i, to: Vector2i) -> void:
	if _carver == null:
		_carver = AStarGrid2D.new()
		_carver.region = Rect2i(0, 0, w, h)
		_carver.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		_carver.update()
		for y in h:
			for x in w:
				_carver.set_point_weight_scale(Vector2i(x, y), _carve_cost(map.get_terrain(Vector2i(x, y))))
	var path := _carver.get_id_path(from, to)
	for i in path.size():
		var c: Vector2i = path[i]
		for cc in [c, c + Vector2i(1, 0) if i % 2 == 0 else c + Vector2i(0, 1)]:
			_open(cc, cc == c)
			_open(_mirror_cell(cc), cc == c)


static func _carve_cost(t: int) -> float:
	match t:
		T.FOREST: return 5.0
		T.ROCK: return 9.0
		T.WATER: return 40.0
	return 1.0


## Rend une case praticable. L'eau ne devient gué que sur le tracé lui-même.
func _open(c: Vector2i, on_path: bool) -> void:
	if not map.is_inside(c):
		return
	var t: int = map.get_terrain(c)
	if t == T.FOREST or t == T.ROCK:
		map.set_tile(c, _floor(c))
	elif t == T.WATER and on_path:
		map.set_tile(c, T.FORD)
	_carver.set_point_weight_scale(c, _carve_cost(map.get_terrain(c)))


## Toute case praticable non reliée au départ devient forêt (pas de poche inaccessible).
func _remove_unreachable(base: Vector2i) -> void:
	var seen := {}
	var stack: Array[Vector2i] = [base]
	seen[base] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if map.is_inside(n) and not seen.has(n) and not (map.get_terrain(n) in GameMap.BLOCKING_TERRAIN):
				seen[n] = true
				stack.append(n)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not seen.has(c) and not (map.get_terrain(c) in GameMap.BLOCKING_TERRAIN):
				map.set_tile(c, T.FOREST)
