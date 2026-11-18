class_name UiUtil
extends RefCounted
## Outils de construction de l'interface d'après la maquette
## (assets/ui/mockup/interface_mockup.png, découpée par tools/extract_ui.py).
## Les positions sont celles de la maquette, qui est aussi la résolution de base.

const BASE := Vector2(1672, 941)
const HUD_DIR := "res://assets/ui/hud/"
const FONT_BOLD := "res://assets/fonts/AlegreyaSans-Bold.ttf"
const COLOR_TEXT := Color(0.96, 0.93, 0.86)
const COLOR_GAIN := Color(0.55, 0.95, 0.45)
const COLOR_LOSS := Color(1.0, 0.45, 0.4)
const COLOR_GOLD := Color(1.0, 0.82, 0.4)


static func tex(name: String) -> Texture2D:
	return load(HUD_DIR + name + ".png")


## Ancre `ctrl` sur un coin / bord de l'écran (h, v : 0 = gauche/haut, 0.5 = centre,
## 1 = droite/bas) en gardant la position `pos` de la maquette.
static func anchor(ctrl: Control, pos: Vector2, size: Vector2, h: float, v: float) -> void:
	ctrl.anchor_left = h
	ctrl.anchor_right = h
	ctrl.anchor_top = v
	ctrl.anchor_bottom = v
	ctrl.offset_left = pos.x - h * BASE.x
	ctrl.offset_top = pos.y - v * BASE.y
	ctrl.offset_right = ctrl.offset_left + size.x
	ctrl.offset_bottom = ctrl.offset_top + size.y


## Image de la maquette posée et ancrée ; bloque les clics vers la carte.
static func panel(parent: Control, name: String, pos: Vector2, h: float, v: float) -> TextureRect:
	var t := TextureRect.new()
	t.name = name
	t.texture = tex(name)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(t)
	anchor(t, pos, t.texture.get_size(), h, v)
	return t


## Zone cliquable invisible posée sur un bouton dessiné dans la maquette.
## `rect` est relatif au parent.
static func hotspot(parent: Control, rect: Rect2, tooltip: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = rect.position
	b.size = rect.size
	b.tooltip_text = tooltip
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.10)))
	b.add_theme_stylebox_override("pressed", _box(Color(1, 0.8, 0.3, 0.22)))
	b.add_theme_stylebox_override("disabled", _box(Color(0.05, 0.03, 0.1, 0.55)))
	parent.add_child(b)
	return b


static func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	return s


static func label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color = COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", load(FONT_BOLD))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Sprite pixel art affiché net (filtre « plus proche voisin »).
static func pixel_icon(parent: Control, texture: Texture2D, rect: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.position = rect.position
	t.size = rect.size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t
