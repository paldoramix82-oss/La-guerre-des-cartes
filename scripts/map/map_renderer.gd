class_name MapRenderer
extends Node2D
## Rendu de la carte à partir des sprites du pack (assets/sprites/nature, props).
## Purement visuel : aucune influence sur le gameplay (la logique reste dans GameMap).
## Les décorations sont placées de façon déterministe (hash de la case).

const NATURE := "res://assets/sprites/nature/"
const PROPS := "res://assets/sprites/props/"

## Sprites dessinés sur les cases infranchissables, selon la zone.
const OBSTACLE_JUNGLE := ["tree_dark", "tree_1", "pine_0", "tree_2", "pine_1"]
const OBSTACLE_ROCK := ["rock_big", "rock_moss", "rock_1"]
## Petites décorations au sol (sans effet), avec leur probabilité.
const DECOR_KINGDOM := ["grass_0", "grass_1", "flowers_0", "flowers_1", "flowers_2"]
const DECOR_JUNGLE := ["bush_0", "bush_1", "bush_dark", "grass_0", "grass_1", "mushrooms", "bush_berry", "stump", "log"]
const DECOR_WATER := ["lily", "reeds"]
const DECOR_CHANCE := 0.22
const WATER_DECOR_CHANCE := 0.12

const GROUND_COLORS := {
	GameMap.Terrain.KINGDOM: Color(0.40, 0.56, 0.30),
	GameMap.Terrain.JUNGLE: Color(0.20, 0.38, 0.22),
	GameMap.Terrain.WATER: Color(0.18, 0.38, 0.66),
	GameMap.Terrain.FORD: Color(0.52, 0.58, 0.62),
	GameMap.Terrain.ROCK: Color(0.24, 0.34, 0.22),
	GameMap.Terrain.FOREST: Color(0.13, 0.28, 0.16),
}

var map: GameMap
var _tex: Dictionary = {}


func _ready() -> void:
	queue_redraw()


func _texture(dir: String, name: String) -> Texture2D:
	var key := dir + name
	if not _tex.has(key):
		_tex[key] = load(key + ".png")
	return _tex[key]


static func _hash(cell: Vector2i, salt: int = 0) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791))


func _pick(list: Array, cell: Vector2i, salt: int) -> String:
	return list[_hash(cell, salt) % list.size()]


func _chance(cell: Vector2i, salt: int) -> float:
	return float(_hash(cell, salt) % 1000) / 1000.0


func _draw() -> void:
	if map == null or map.tiles.is_empty():
		return
	var ts := GameConfig.TILE_SIZE
	# 1. Sol.
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			var terrain := map.get_terrain(cell)
			var col: Color = GROUND_COLORS[terrain]
			# Légère variation pour casser l'aspect damier.
			col = col.darkened(0.04 * float(_hash(cell, 7) % 3))
			draw_rect(Rect2(Vector2(cell) * ts, Vector2(ts, ts)), col)
	# 2. Décorations au sol.
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			match map.get_terrain(cell):
				GameMap.Terrain.KINGDOM:
					if _chance(cell, 1) < DECOR_CHANCE:
						_draw_small(_texture(NATURE, _pick(DECOR_KINGDOM, cell, 2)), cell)
				GameMap.Terrain.JUNGLE:
					if _chance(cell, 1) < DECOR_CHANCE:
						_draw_small(_texture(NATURE, _pick(DECOR_JUNGLE, cell, 2)), cell)
				GameMap.Terrain.WATER:
					_draw_water(cell)
				GameMap.Terrain.FORD:
					if _chance(cell, 3) < 0.5:
						_draw_small(_texture(NATURE, "rock_sand"), cell)
	# 3. Frontières des royaumes.
	var border := Color(1, 1, 1, 0.22)
	for bx in [map.kingdom_depth, map.width - map.kingdom_depth]:
		draw_line(Vector2(bx * ts, 0), Vector2(bx * ts, map.height * ts), border, 2.0)
	# 4. Repères : camps de monstres, repaires des boss, départs des joueurs.
	for c in map.features.get(&"camps", []):
		_draw_obstacle(_texture(PROPS, "bones"), c)
		_draw_obstacle(_texture(PROPS, "campfire"), c + Vector2i(1, 0))
	var lairs: Dictionary = map.features.get(&"lairs", {})
	if lairs.has(&"dragon"):
		_draw_obstacle(_texture(PROPS, "cave"), lairs[&"dragon"] + Vector2i(0, -2))
		_draw_obstacle(_texture(PROPS, "chest"), lairs[&"dragon"] + Vector2i(1, -2))
	if lairs.has(&"witch"):
		_draw_obstacle(_texture(PROPS, "cauldron"), lairs[&"witch"] + Vector2i(0, 2))
		_draw_obstacle(_texture(PROPS, "altar"), lairs[&"witch"] + Vector2i(-1, 2))
	var bases: Array = map.features.get(&"bases", [])
	for team in bases.size():
		_draw_base(team, bases[team])
	# 5. Obstacles : arbres et rochers (ligne par ligne pour que les plus bas passent devant).
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			match map.get_terrain(cell):
				GameMap.Terrain.FOREST:
					_draw_obstacle(_texture(NATURE, _pick(OBSTACLE_JUNGLE, cell, 4)), cell)
				GameMap.Terrain.ROCK:
					_draw_obstacle(_texture(NATURE, _pick(OBSTACLE_ROCK, cell, 4)), cell)


## Eau : reflets, nénuphars et roseaux (sur les bords).
func _draw_water(cell: Vector2i) -> void:
	var ts := float(GameConfig.TILE_SIZE)
	var center := map.cell_to_world(cell)
	if _chance(cell, 5) < 0.18:
		var wave := _texture("res://assets/sprites/glyphs/", "wave")
		draw_texture_rect(wave, Rect2(center - Vector2(8, 8), Vector2(16, 16)), false, Color(0.75, 0.88, 1.0, 0.35))
	var shore := false
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = cell + d
		if map.is_inside(n) and map.get_terrain(n) != GameMap.Terrain.WATER and map.get_terrain(n) != GameMap.Terrain.FORD:
			shore = true
	if shore and _chance(cell, 1) < 0.35:
		_draw_small(_texture(NATURE, "reeds"), cell)
	elif _chance(cell, 1) < WATER_DECOR_CHANCE:
		_draw_small(_texture(NATURE, "lily"), cell)


## Petit sprite 16 px, centré avec un léger décalage aléatoire.
func _draw_small(tex: Texture2D, cell: Vector2i) -> void:
	var jitter := Vector2(_hash(cell, 5) % 9 - 4, _hash(cell, 6) % 9 - 4)
	draw_texture(tex, map.cell_to_world(cell) - tex.get_size() * 0.5 + jitter)


## Obstacle posé au sol : pied aligné sur le bas de la case, mis à l'échelle de la case.
func _draw_obstacle(tex: Texture2D, cell: Vector2i) -> void:
	var ts := float(GameConfig.TILE_SIZE)
	var scale := 2.0 if tex.get_size().x <= 16 else 1.25
	var size := tex.get_size() * scale
	var bottom := map.cell_to_world(cell) + Vector2(0, ts * 0.5)
	draw_texture_rect(tex, Rect2(bottom - Vector2(size.x * 0.5, size.y), size), false)


## Départ d'un joueur (emplacement du futur château) : tentes, bannière, feu de camp.
func _draw_base(team: int, base: Vector2i) -> void:
	var dir := 1 if team == 0 else -1
	_draw_obstacle(_texture(PROPS, "campfire"), base)
	_draw_obstacle(_texture(PROPS, "banner_blue" if team == 0 else "banner"), base + Vector2i(0, -2))
	for off in [Vector2i(-2 * dir, -1), Vector2i(-2 * dir, 2)]:
		_draw_obstacle(_texture(PROPS, "tent_blue" if team == 0 else "tent_red"), base + off)
