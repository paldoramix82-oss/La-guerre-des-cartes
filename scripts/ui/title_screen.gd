extends Control
## Écran titre : fond, titre, boutons Jouer / Quitter, musique.

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

	# Titre écrit (le logo du pack porte le nom d'un autre jeu).
	var title := Label.new()
	title.text = "La Guerre des Cartes"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.25))
	title.add_theme_constant_override("outline_size", 14)
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Prototype 1 — Carte, déplacements, sélection, combats"
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
