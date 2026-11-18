class_name Hud
extends CanvasLayer
## Interface du prototype : équipe contrôlée, aide (en haut à gauche) et
## escouades sélectionnées avec portrait (en bas).

## Émis par les boutons : &"select_all", &"stop", &"deselect", &"zoom_in", &"zoom_out", &"switch_team".
signal command(name: StringName)

const HELP := "Clic sur une escouade : la choisir · Glisser : en choisir plusieurs\n" \
	+ "Puis clic sur le terrain : y aller · Clic sur un ennemi : attaquer\n" \
	+ "Option + clic sur un allié : soigner (Soigneur)\n" \
	+ "Vue : glisser à 2 doigts ou flèches · Zoom : pincer ou + / −"

const BUTTONS := [
	[&"select_all", "Tout choisir", "Cmd + A"],
	[&"deselect", "Aucun", "Échap"],
	[&"stop", "Stop", "Espace"],
	[&"zoom_out", "−", "Touche -"],
	[&"zoom_in", "+", "Touche +"],
	[&"switch_team", "Équipe", "Tab : contrôler l'autre joueur (test)"],
]

var _team_label: Label
var _selection_box: HBoxContainer
var _selection_panel: PanelContainer
var _selection: Array[Squad] = []
var _team := 0
var _dirty := true


func _ready() -> void:
	# Panneau d'aide.
	var help_panel := PanelContainer.new()
	help_panel.position = Vector2(12, 12)
	var help_vbox := VBoxContainer.new()
	_team_label = Label.new()
	_team_label.theme_type_variation = &"TitleLabel"
	help_vbox.add_child(_team_label)
	var help := Label.new()
	help.text = HELP
	help.add_theme_font_size_override("font_size", 14)
	help_vbox.add_child(help)
	help_panel.add_child(help_vbox)
	add_child(help_panel)

	# Barre de boutons (en haut à droite) : toutes les commandes sans clavier.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_right = -12
	bar.offset_top = 12
	for def in BUTTONS:
		var b := Button.new()
		b.text = def[1]
		b.tooltip_text = def[2]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.custom_minimum_size = Vector2(44, 40)
		var cmd: StringName = def[0]
		b.pressed.connect(func(): command.emit(cmd))
		bar.add_child(b)
	add_child(bar)

	# Barre de sélection en bas de l'écran.
	_selection_panel = PanelContainer.new()
	_selection_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_selection_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_selection_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_selection_panel.offset_bottom = -12
	_selection_box = HBoxContainer.new()
	_selection_box.add_theme_constant_override("separation", 8)
	_selection_panel.add_child(_selection_box)
	add_child(_selection_panel)
	_refresh()


func _process(_delta: float) -> void:
	# Rafraîchissement léger : PV et états changent en continu.
	_refresh()


func on_selection_changed(selection: Array[Squad]) -> void:
	_selection = selection.duplicate()
	_dirty = true


func on_team_changed(team: int) -> void:
	_team = team
	_dirty = true


func _refresh() -> void:
	_team_label.text = "Vous contrôlez : %s" % GameConfig.TEAM_NAMES[_team]
	_team_label.add_theme_color_override("font_color", GameConfig.TEAM_COLORS[_team].lightened(0.3))
	_selection = _selection.filter(func(s): return is_instance_valid(s) and s.is_alive())
	_selection_panel.visible = not _selection.is_empty()
	if _dirty or _selection_box.get_child_count() != _selection.size():
		_rebuild_cards()
	for i in _selection.size():
		_update_card(_selection_box.get_child(i), _selection[i])


func _rebuild_cards() -> void:
	_dirty = false
	for c in _selection_box.get_children():
		_selection_box.remove_child(c)
		c.queue_free()
	for s in _selection:
		_selection_box.add_child(_make_card(s))


func _make_card(s: Squad) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"SlotPanel"
	var hb := HBoxContainer.new()
	var portrait := TextureRect.new()
	portrait.texture = s.data.sprite
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.name = "Title"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 14)
	vb.add_child(title)
	var info := Label.new()
	info.name = "Info"
	info.add_theme_font_size_override("font_size", 13)
	vb.add_child(info)
	hb.add_child(vb)
	card.add_child(hb)
	return card


func _update_card(card: Control, s: Squad) -> void:
	var vb := card.get_child(0).get_child(1)
	vb.get_node("Title").text = s.data.display_name
	var status: String = ["Repos", "Déplacement", "Soin" if s.data.action == UnitData.ActionType.HEAL else "Combat"][s.state]
	if s.is_burning():
		status += " · Brûlure"
	vb.get_node("Info").text = "%d/%d individus\n%d/%d PV · %s" % [
		s.alive_count(), s.data.squad_size, s.total_hp(), s.data.max_total_hp(), status]
