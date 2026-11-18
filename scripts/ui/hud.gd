class_name Hud
extends CanvasLayer
## Interface du prototype : équipe contrôlée, aide (en haut à gauche) et
## escouades sélectionnées avec portrait (en bas).

## Émis par les boutons : &"select_all", &"stop", &"deselect", &"zoom_in", &"zoom_out", &"switch_team".
signal command(name: StringName)
## Bouton du menu Construire.
signal build_requested(data: BuildingData)

## Icônes des ressources (assets/sprites/items/).
const RESOURCE_ICONS := {
	&"gold": "res://assets/sprites/items/coin.png",
	&"wood": "res://assets/sprites/nature/log.png",
	&"metal": "res://assets/sprites/items/ore.png",
	&"organic": "res://assets/sprites/items/herb.png",
	&"food": "res://assets/sprites/items/food.png",
}
const NOTICE_DURATION := 3.0

const HELP := "Clic sur une escouade : la choisir · Glisser : en choisir plusieurs\n" \
	+ "Puis clic sur le terrain : y aller · Clic sur un ennemi : attaquer\n" \
	+ "Ouvriers + clic sur un gisement / chantier : récolter / construire\n" \
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
var economy_system: EconomySystem
var _resource_labels: Dictionary = {}
var _build_buttons: Array = []
var _notice: Label
var _notice_time := 0.0
var _build_hint: Label


func _ready() -> void:
	# Panneau d'aide.
	var help_panel := PanelContainer.new()
	help_panel.position = Vector2(12, 62)
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
	_build_resource_bar()
	_build_menu()
	_notice = Label.new()
	_notice.theme_type_variation = &"TitleLabel"
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice.offset_top = 70
	_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_notice.add_theme_constant_override("outline_size", 6)
	add_child(_notice)
	_refresh()


# --- Ressources -----------------------------------------------------------------

func _build_resource_bar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 8)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	for r in ResourceTypes.ALL:
		var icon := TextureRect.new()
		icon.texture = load(RESOURCE_ICONS[r])
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = ResourceTypes.NAMES[r]
		hb.add_child(icon)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 15)
		l.tooltip_text = ResourceTypes.NAMES[r]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		hb.add_child(l)
		_resource_labels[r] = l
	panel.add_child(hb)
	add_child(panel)


func _refresh_resources() -> void:
	if economy_system == null:
		return
	var econ := economy_system.economy(_team)
	for r in ResourceTypes.ALL:
		var l: Label = _resource_labels[r]
		l.text = "%d / %d" % [econ.get_amount(r), econ.capacity(r)]
		var warn := r == ResourceTypes.FOOD and econ.get_amount(r) == 0
		l.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if warn else Color(0.93, 0.9, 1))


# --- Menu Construire ------------------------------------------------------------

func _build_menu() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 12
	panel.offset_bottom = -12
	var vb := VBoxContainer.new()
	var title := Label.new()
	title.text = "Construire"
	title.theme_type_variation = &"TitleLabel"
	vb.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var list := BuildingDatabase.load_all().values().filter(func(b): return b.player_buildable)
	list.sort_custom(func(a, b): return [a.category, a.display_name] < [b.category, b.display_name])
	for data in list:
		var b := Button.new()
		b.text = data.display_name
		b.icon = data.sprite
		b.expand_icon = false
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_constant_override("icon_max_width", 20)
		b.custom_minimum_size = Vector2(150, 34)
		b.tooltip_text = _building_tooltip(data)
		b.pressed.connect(func(): build_requested.emit(data))
		grid.add_child(b)
		_build_buttons.append([b, data])
	vb.add_child(grid)
	_build_hint = Label.new()
	_build_hint.add_theme_font_size_override("font_size", 13)
	_build_hint.text = "Survolez un bouton pour voir le coût."
	vb.add_child(_build_hint)
	panel.add_child(vb)
	add_child(panel)
	for pair in _build_buttons:
		var btn: Button = pair[0]
		var d: BuildingData = pair[1]
		btn.mouse_entered.connect(func(): _build_hint.text = "%s : %s" % [d.display_name, ResourceTypes.format(d.cost)])


static func _building_tooltip(d: BuildingData) -> String:
	var lines := [d.display_name, "Coût : " + ResourceTypes.format(d.cost)]
	lines.append("Construction : " + ("immédiate" if d.build_turns == 0 else "%d tours (1 ouvrier)" % d.build_turns))
	if not d.storage.is_empty():
		lines.append("Stockage : +" + ResourceTypes.format(d.storage))
	if not d.production.is_empty():
		lines.append("Production / tour : " + ResourceTypes.format(d.production))
	if not d.upkeep.is_empty():
		lines.append("Consommation / tour : " + ResourceTypes.format(d.upkeep))
	if d.workers > 0:
		lines.append("Fournit %d ouvriers" % d.workers)
	return "\n".join(lines)


func _refresh_build_buttons() -> void:
	if economy_system == null:
		return
	var econ := economy_system.economy(_team)
	for pair in _build_buttons:
		pair[0].disabled = not econ.can_afford(pair[1].cost)


func show_notice(text: String) -> void:
	_notice.text = text
	_notice_time = NOTICE_DURATION


func on_build_mode_changed(data: BuildingData) -> void:
	if data:
		show_notice("Placer : %s — clic dans votre royaume · Échap pour annuler" % data.display_name)
	else:
		_notice_time = 0.0



func _process(delta: float) -> void:
	# Rafraîchissement léger : PV, états et ressources changent en continu.
	_refresh()
	_refresh_resources()
	_refresh_build_buttons()
	_notice_time -= delta
	_notice.visible = _notice_time > 0.0


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
	var status: String = ["Repos", "Déplacement", "Soin" if s.data.action == UnitData.ActionType.HEAL else "Combat",
			"Construction" if s.work_target is Building else "Récolte"][s.state]
	if s.state == Squad.State.WORKING and not s.is_fed():
		status += " (sans nourriture)"
	if s.is_burning():
		status += " · Brûlure"
	vb.get_node("Info").text = "%d/%d individus\n%d/%d PV · %s" % [
		s.alive_count(), s.data.squad_size, s.total_hp(), s.data.max_total_hp(), status]
