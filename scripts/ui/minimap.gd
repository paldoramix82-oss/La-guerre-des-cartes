class_name Minimap
extends Control
## Mini-carte : terrain, gisements, bâtiments, individus et cadre de la vue.
## Clic (ou glisser) pour déplacer la caméra.

const REDRAW_INTERVAL := 0.2
const UNIT_DOT := 2.0

var map: GameMap
var camera: Camera2D
var _terrain: ImageTexture
var _timer := 0.0
var _dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Mini-carte : cliquez pour y déplacer la vue"


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REDRAW_INTERVAL
		queue_redraw()


## Rectangle (local) où la carte est dessinée, proportions conservées.
func map_rect() -> Rect2:
	if map == null:
		return Rect2()
	var ratio := float(map.width) / map.height
	var w := size.x
	var h := w / ratio
	if h > size.y:
		h = size.y
		w = h * ratio
	return Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))


func _terrain_texture() -> Texture2D:
	if _terrain == null and map and not map.tiles.is_empty():
		var img := Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
		for y in map.height:
			for x in map.width:
				img.set_pixel(x, y, MapRenderer.GROUND_COLORS[map.get_terrain(Vector2i(x, y))])
		_terrain = ImageTexture.create_from_image(img)
	return _terrain


func _draw() -> void:
	var t := _terrain_texture()
	if t == null:
		return
	var r := map_rect()
	var cell := r.size.x / map.width
	draw_texture_rect(t, r, false)
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		var col: Color = Color(1, 0.85, 0.3) if o is Deposit else GameConfig.TEAM_COLORS[o.team].lightened(0.2)
		draw_rect(Rect2(r.position + Vector2(o.cell) * cell, Vector2(cell, cell)), col)
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var m := n as Individual
		if m and m.is_alive():
			var p := r.position + m.position / GameConfig.TILE_SIZE * cell
			draw_rect(Rect2(p - Vector2(UNIT_DOT, UNIT_DOT) * 0.5, Vector2(UNIT_DOT, UNIT_DOT)), GameConfig.TEAM_COLORS[m.team])
	if camera:
		var view := get_viewport().get_visible_rect().size / camera.zoom
		var top_left := camera.position - view * 0.5
		var vr := Rect2(r.position + top_left / GameConfig.TILE_SIZE * cell, view / GameConfig.TILE_SIZE * cell)
		draw_rect(vr.intersection(r), Color(1, 1, 1, 0.9), false, 1.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_move_camera(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_move_camera(event.position)
		accept_event()


func _move_camera(local: Vector2) -> void:
	if camera == null or map == null:
		return
	var r := map_rect()
	var cell := r.size.x / map.width
	camera.position = (local - r.position) / cell * GameConfig.TILE_SIZE
	if camera.has_method("pan"):
		camera.pan(Vector2.ZERO)  # recadre dans les limites de la carte
	queue_redraw()
