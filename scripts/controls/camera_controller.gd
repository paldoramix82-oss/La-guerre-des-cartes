class_name CameraController
extends Camera2D
## Caméra RTS, utilisable au trackpad (Mac) comme à la souris :
##   Glisser à deux doigts (ou molette)      : déplacer la vue
##   Pincer (ou Cmd/Ctrl + molette), + / -   : zoomer
##   Flèches, ZQSD (AZERTY) / WASD (QWERTY)  : déplacer la vue
##   Clic molette maintenu                   : faire glisser la vue

@export var pan_speed := 700.0
## Sensibilité du glisser à deux doigts / de la molette.
@export var scroll_speed := 22.0
@export var zoom_step := 1.2
@export var min_zoom := 1.0
@export var max_zoom := 5.0

var bounds := Rect2()
var _middle_drag := false


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO:
		pan(dir.normalized() * pan_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventPanGesture:
		# Trackpad : glisser à deux doigts.
		pan(event.delta * scroll_speed)
	elif event is InputEventMagnifyGesture:
		# Trackpad : pincer pour zoomer.
		set_zoom_level(zoom.x * event.factor)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var zoom_mod := mb.ctrl_pressed or mb.meta_pressed
		var f := mb.factor if mb.factor > 0.0 else 1.0
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if zoom_mod: zoom_in()
				else: pan(Vector2(0, -scroll_speed * f))
			MOUSE_BUTTON_WHEEL_DOWN:
				if zoom_mod: zoom_out()
				else: pan(Vector2(0, scroll_speed * f))
			MOUSE_BUTTON_WHEEL_LEFT:
				pan(Vector2(-scroll_speed * f, 0))
			MOUSE_BUTTON_WHEEL_RIGHT:
				pan(Vector2(scroll_speed * f, 0))
			MOUSE_BUTTON_MIDDLE:
				_middle_drag = mb.pressed
	elif event is InputEventMouseMotion and _middle_drag:
		position -= event.relative / zoom.x
		_clamp()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
				zoom_in()
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_out()


## Déplace la vue de `screen_delta` pixels écran.
func pan(screen_delta: Vector2) -> void:
	position += screen_delta / zoom.x
	_clamp()


func zoom_in() -> void:
	set_zoom_level(zoom.x * zoom_step)


func zoom_out() -> void:
	set_zoom_level(zoom.x / zoom_step)


func set_zoom_level(z: float) -> void:
	z = clampf(z, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	_clamp()


func _clamp() -> void:
	if bounds.size != Vector2.ZERO:
		position = position.clamp(bounds.position, bounds.end)
