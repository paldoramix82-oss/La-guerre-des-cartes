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
			var terrain := map.get_terrain(cell)
			match terrain:
				GameMap.Terrain.KINGDOM:
					if _chance(cell, 1) < DECOR_CHANCE:
						_draw_small(_texture(NATURE, _pick(DECOR_KINGDOM, cell, 2)), cell)
				GameMap.Terrain.JUNGLE:
					if _chance(cell, 1) < DECOR_CHANCE:
						_draw_small(_texture(NATURE, _pick(DECOR_JUNGLE, cell, 2)), cell)
				GameMap.Terrain.WATER:
					if _chance(cell, 1) < WATER_DECOR_CHANCE:
						_draw_small(_texture(NATURE, _pick(DECOR_WATER, cell, 2)), cell)
				GameMap.Terrain.FORD:
					_draw_small(_texture(NATURE, "rock_sand"), cell)
	# 3. Frontières des royaumes.
	var border := Color(1, 1, 1, 0.25)
	for bx in [GameConfig.KINGDOM_DEPTH, map.width - GameConfig.KINGDOM_DEPTH]:
		draw_line(Vector2(bx * ts, 0), Vector2(bx * ts, map.height * ts), border, 2.0)
	# 4. Obstacles (ligne par ligne pour que les plus bas passent devant).
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if map.get_terrain(cell) != GameMap.Terrain.ROCK:
				continue
			var list: Array = OBSTACLE_ROCK if _hash(cell, 3) % 3 == 0 else OBSTACLE_JUNGLE
			_draw_obstacle(_texture(NATURE, _pick(list, cell, 4)), cell)
	# 5. Campements décoratifs des deux royaumes (pas encore de bâtiments : Prototype 2).
	_draw_camp(0, "tent_blue", "banner_blue")
	_draw_camp(1, "tent_red", "banner")


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


func _draw_camp(team: int, tent: String, banner: String) -> void:
	var x := 2 if team == 0 else map.width - 3
	var y := map.height / 2
	for dy in [-6, 6]:
		_draw_obstacle(_texture(PROPS, tent), Vector2i(x, y + dy))
	_draw_obstacle(_texture(PROPS, banner), Vector2i(x, y - 8))
	_draw_obstacle(_texture(PROPS, "campfire"), Vector2i(x, y))
