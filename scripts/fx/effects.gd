class_name Effects
extends Node2D
## Calque des effets visuels (purement cosmétiques, sans effet sur le jeu) :
## projectiles, chiffres de dégâts / soins, éclats sur les cases d'une zone.
## Les fonctions statiques cherchent le calque dans l'arbre ; sans calque
## (tests), elles ne font rien.

const GROUP := &"effects_layer"
const PROJECTILE_SPEED := 360.0  ## pixels / seconde
const TEXT_DURATION := 0.8
const BURST_DURATION := 0.35


func _enter_tree() -> void:
	add_to_group(GROUP)
	z_index = 50


static func _layer(from: Node) -> Effects:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP) as Effects


## Projectile de `from` à `to` : sprite teinté, orienté (`angle_offset` = angle
## propre du dessin), puis petit éclat à l'arrivée.
static func projectile(source: Node, from: Vector2, to: Vector2, tex: Texture2D, color: Color, angle_offset: float) -> void:
	var layer := _layer(source)
	if layer == null or tex == null:
		return
	var p := _Projectile.new()
	p.texture = tex
	p.modulate = color
	p.start = from
	p.end = to
	p.duration = maxf(0.08, from.distance_to(to) / PROJECTILE_SPEED)
	p.rotation = (to - from).angle() - angle_offset
	p.position = from
	layer.add_child(p)


## Chiffre flottant (ex. « -10 » en rouge, « +5 » en vert).
static func floating_text(source: Node, pos: Vector2, text: String, color: Color) -> void:
	var layer := _layer(source)
	if layer == null:
		return
	var t := _FloatingText.new()
	t.text = text
	t.color = color
	t.position = pos + Vector2(randf_range(-4, 4), -14)
	layer.add_child(t)


## Éclat sur des cases (zone du Mage, cercle du Cavalier, soin).
static func burst(source: Node, positions: Array, color: Color) -> void:
	var layer := _layer(source)
	if layer == null:
		return
	for pos in positions:
		var b := _Burst.new()
		b.color = color
		b.position = pos
		layer.add_child(b)


class _Projectile:
	extends Sprite2D
	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var duration := 0.2
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var k := minf(_t / duration, 1.0)
		# Légère courbe pour les tirs longs (lisibilité).
		var arc := -sin(k * PI) * minf(start.distance_to(end) * 0.12, 18.0)
		position = start.lerp(end, k) + Vector2(0, arc)
		if k >= 1.0:
			Effects.burst(self, [end], Color(modulate, 0.8))
			queue_free()


class _FloatingText:
	extends Node2D
	var text := ""
	var color := Color.WHITE
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		position.y -= 22.0 * delta
		modulate.a = 1.0 - _t / Effects.TEXT_DURATION
		if _t >= Effects.TEXT_DURATION:
			queue_free()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-12, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 24, 11, 3, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(-12, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 24, 11, color)


class _Burst:
	extends Node2D
	var color := Color.WHITE
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= Effects.BURST_DURATION:
			queue_free()

	func _draw() -> void:
		var k := _t / Effects.BURST_DURATION
		var r := GameConfig.TILE_SIZE * (0.15 + 0.4 * k)
		draw_circle(Vector2.ZERO, r, Color(color, 0.35 * (1.0 - k)))
		draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(color, 0.9 * (1.0 - k)), 2.0)
