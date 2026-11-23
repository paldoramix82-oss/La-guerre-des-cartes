class_name FogOfWar
extends Node2D
## Brouillard de guerre (décision de l'auteur) pour le joueur contrôlé :
## - case jamais explorée : noire ;
## - case explorée mais hors de vue : assombrie, sans les unités ennemies ;
## - case en vue : claire.
## Vision d'un individu = son déplacement + GameConfig.VISION_BONUS cases.
## [PROVISOIRE] Bâtiments terminés : GameConfig.BUILDING_VISION ; point de départ : BASE_VISION.
## Les ennemis hors de vue sont cachés (unités) ; leurs bâtiments restent visibles
## une fois découverts. Le calcul est purement visuel : il ne change pas les règles.

const GROUP := &"fog_of_war"
const UPDATE_INTERVAL := 0.15
const ALPHA_UNEXPLORED := 255
const ALPHA_EXPLORED := 140

var map: GameMap
var team := 0
## Par équipe : PackedByteArray (1 = exploré).
var _explored: Array = []
## Cases actuellement en vue (équipe contrôlée) : 1 = en vue.
var _visible := PackedByteArray()
var _image: Image
var _texture: ImageTexture
var _timer := 0.0
## Par équipe : bâtiments ennemis déjà aperçus {Building: true}.
var _seen_buildings: Array = [{}, {}]


func _enter_tree() -> void:
	add_to_group(GROUP)
	z_index = 60


func setup(p_map: GameMap, p_team: int) -> void:
	map = p_map
	team = p_team
	_explored.clear()
	for t in 2:
		var e := PackedByteArray()
		e.resize(map.width * map.height)
		_explored.append(e)
	_visible.resize(map.width * map.height)
	_image = Image.create(map.width, map.height, false, Image.FORMAT_LA8)
	_texture = ImageTexture.create_from_image(_image)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	update_now()


func set_team(t: int) -> void:
	team = t
	update_now()


static func of(node: Node) -> FogOfWar:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as FogOfWar


func is_cell_visible(cell: Vector2i) -> bool:
	if not map.is_inside(cell):
		return false
	return _visible[cell.y * map.width + cell.x] == 1


func is_explored(cell: Vector2i, t: int = -1) -> bool:
	if not map.is_inside(cell):
		return false
	return _explored[team if t < 0 else t][cell.y * map.width + cell.x] == 1


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		update_now()


func update_now() -> void:
	if map == null:
		return
	_visible.fill(0)
	for t in 2:
		var sources := _vision_sources(t)
		for src in sources:
			_reveal(t, src[0], src[1])
	_apply_visibility()
	_refresh_texture()


## Sources de vision de l'équipe `t` : [case, rayon].
func _vision_sources(t: int) -> Array:
	var out: Array = [[map.base_of(t), GameConfig.BASE_VISION]]
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var m := n as Individual
		if m and m.is_alive() and m.team == t:
			out.append([m.get_cell(), int(m.data.move_speed) + GameConfig.VISION_BONUS])
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		if o is Building and o.team == t and o.is_complete:
			# Une défense voit au moins jusqu'à sa portée.
			out.append([o.cell, maxi(GameConfig.BUILDING_VISION, o.data.attack_range if o.turret else 0)])
	return out


func _reveal(t: int, center: Vector2i, radius: int) -> void:
	var explored: PackedByteArray = _explored[t]
	var r2 := (radius + 0.5) * (radius + 0.5)
	for dy in range(-radius, radius + 1):
		var y := center.y + dy
		if y < 0 or y >= map.height:
			continue
		for dx in range(-radius, radius + 1):
			var x := center.x + dx
			if x < 0 or x >= map.width or dx * dx + dy * dy > r2:
				continue
			var i := y * map.width + x
			explored[i] = 1
			if t == team:
				_visible[i] = 1
	_explored[t] = explored


## Cache les unités ennemies hors de vue, et les bâtiments ennemis jamais découverts.
func _apply_visibility() -> void:
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var m := n as Individual
		if m:
			m.visible = (m.team == team or is_cell_visible(m.get_cell())) and not m.squad.sheltered
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		if o is Building and o.team != team:
			if is_cell_visible(o.cell):
				_seen_buildings[team][o] = true
			o.visible = _seen_buildings[team].has(o)
		elif o is MapObject:
			o.visible = is_explored(o.cell)


func _refresh_texture() -> void:
	var data := PackedByteArray()
	data.resize(map.width * map.height * 2)
	var explored: PackedByteArray = _explored[team]
	for i in map.width * map.height:
		data[i * 2] = 0
		if _visible[i] == 1:
			data[i * 2 + 1] = 0
		elif explored[i] == 1:
			data[i * 2 + 1] = ALPHA_EXPLORED
		else:
			data[i * 2 + 1] = ALPHA_UNEXPLORED
	_image.set_data(map.width, map.height, false, Image.FORMAT_LA8, data)
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	if _texture:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, map.world_size()), false)
