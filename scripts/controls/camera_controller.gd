class_name CameraController
extends Camera2D
## Caméra RTS : ZQSD (AZERTY) / WASD (QWERTY) ou flèches pour se déplacer, molette pour zoomer,
## clic molette maintenu pour faire glisser la vue.

@export var pan_speed := 900.0
@export var zoom_step := 1.15
@export var min_zoom := 0.5
@export var max_zoom := 3.0

var bounds := Rect2()
var _middle_drag := false


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * pan_speed * delta / zoom.x
		_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(zoom.x * zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(zoom.x / zoom_step)
			MOUSE_BUTTON_MIDDLE:
				_middle_drag = event.pressed
	elif event is InputEventMouseMotion and _middle_drag:
		position -= event.relative / zoom.x
		_clamp()


func _set_zoom(z: float) -> void:
	z = clampf(z, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	_clamp()


func _clamp() -> void:
	if bounds.size != Vector2.ZERO:
		position = position.clamp(bounds.position, bounds.end)
