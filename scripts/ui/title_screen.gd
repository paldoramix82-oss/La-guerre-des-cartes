extends Control
## Écran titre : fond, logo, boutons Jouer / Quitter, musique.

const GAME_SCENE := "res://scenes/main.tscn"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/title_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)

	# Logo de la maquette de l'auteur (assets/ui/hud/logo.png).
	var logo := TextureRect.new()
	logo.texture = UiUtil.tex("logo")
	logo.custom_minimum_size = logo.texture.get_size() * 1.3
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(logo)

	var subtitle := Label.new()
	subtitle.text = "Prototype 4 — Jungle, monstres et mines"
	subtitle.theme_type_variation = &"TitleLabel"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(subtitle)

	var play := _button("Jouer", vb)
	play.pressed.connect(func(): get_tree().change_scene_to_file(GAME_SCENE))
	_button("Quitter", vb).pressed.connect(func(): get_tree().quit())
	play.grab_focus()

	add_child(MusicPlayer.create(GameConfig.MUSIC_TITLE))


func _button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b
