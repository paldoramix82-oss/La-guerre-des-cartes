class_name Hud
extends CanvasLayer
## Interface de jeu, disposée comme la maquette de l'auteur
## (assets/ui/mockup/interface_mockup.png, résolution de base 1672 x 941) :
##   haut    : barre de ressources · horloge, pause, accélérer, menu
##   droite  : mini-carte (+ zoom, recentrer) · objectifs · main de cartes
##   bas     : portrait · informations · Construction / Recrutement / Améliorations · commandes
## Les sous-panneaux ont leur propre script (Minimap, BuildPanel, CommandPanel, PauseMenu).

## Commandes : &"select_all", &"stop", &"deselect", &"zoom_in", &"zoom_out", &"switch_team",
## &"center", &"move", &"attack", &"cancel".
signal command(name: StringName)
signal build_requested(data: BuildingData)
signal recruit_requested(unit: UnitData)

const NOTICE_DURATION := 3.0
const HELP := "Clic sur une escouade : la choisir · Glisser : en choisir plusieurs\n" \
	+ "Puis clic sur le terrain : y aller · Clic sur un ennemi : attaquer\n" \
	+ "Ouvriers + clic sur un gisement / chantier : récolter / construire\n" \
	+ "Clic sur votre Caserne puis onglet Recrutement : recruter\n" \
	+ "Option + clic sur un allié : soigner · Tab : contrôler l'autre joueur (test)\n" \
	+ "Vue : glisser à 2 doigts ou flèches · Zoom : pincer ou + / −"

## Ressources de la barre : [ressource, icône (maquette ou pack)].
const BAR_RESOURCES := [
	[&"gold", "hud:icon_gold"],
	[&"wood", "hud:icon_wood"],
	[&"food", "hud:icon_food"],
	[&"metal", "res://assets/sprites/items/ore.png"],
	[&"organic", "res://assets/sprites/items/herb.png"],
]
const BAR_SLOT_X := [30, 154, 278, 402, 526]

var economy_system: EconomySystem
var map: GameMap
var camera: Camera2D

var _root: Control
var _amount_labels: Dictionary = {}
var _rate_labels: Dictionary = {}
var _mana_label: Label
var _mana_rate: Label
var _hand: HandPanel
var card_system: CardSystem
var _clock_label: Label
var _fast_button: TextureButton
var _minimap: Minimap
var _build_panel: BuildPanel
var _portrait: TextureRect
var _portrait_name: Label
var _info: Label
var _notice: Label
var _pause_menu: PauseMenu
var _selection: Array[Squad] = []
var _building: Building = null
var _team := 0
var _game_time := 0.0
var _notice_time := 0.0
var _hover_text := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Les éléments de la maquette sont lissés ; les sprites pixel art restent nets.
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_root)
	_build_top_bar()
	_build_top_right()
	_build_bottom()
	_notice = UiUtil.label(_root, "", Vector2.ZERO, 22, UiUtil.COLOR_GOLD)
	_notice.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_notice.add_theme_constant_override("outline_size", 6)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiUtil.anchor(_notice, Vector2(436, 84), Vector2(840, 30), 0.5, 0)
	_pause_menu = PauseMenu.new()
	_root.add_child(_pause_menu)


## Références au monde (appelé par la scène principale).
func setup(p_map: GameMap, p_camera: Camera2D, p_economy: EconomySystem) -> void:
	map = p_map
	camera = p_camera
	economy_system = p_economy
	_minimap.map = map
	_minimap.camera = camera
	_build_panel.economy_system = economy_system


# --- Construction de l'interface ---------------------------------------------------

func _build_top_bar() -> void:
	var bar := UiUtil.panel(_root, "resource_bar", Vector2(431, 13), 0.5, 0)
	bar.tooltip_text = "Ressources : quantité (revenu net du dernier tour)"
	for i in BAR_RESOURCES.size():
		var r: StringName = BAR_RESOURCES[i][0]
		var icon_path: String = BAR_RESOURCES[i][1]
		var x: float = BAR_SLOT_X[i]
		var icon_tex: Texture2D = UiUtil.tex(icon_path.trim_prefix("hud:")) if icon_path.begins_with("hud:") else load(icon_path)
		UiUtil.pixel_icon(bar, icon_tex, Rect2(x, 14, 34, 34)).texture_filter = \
				CanvasItem.TEXTURE_FILTER_LINEAR if icon_path.begins_with("hud:") else CanvasItem.TEXTURE_FILTER_NEAREST
		_amount_labels[r] = UiUtil.label(bar, "0", Vector2(x + 38, 13), 22)
		_rate_labels[r] = UiUtil.label(bar, "", Vector2(x + 38, 35), 14, UiUtil.COLOR_GAIN)
	# Mana (cristal bleu de la maquette), après le séparateur.
	UiUtil.pixel_icon(bar, UiUtil.tex("icon_mana"), Rect2(682, 12, 36, 38)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mana_label = UiUtil.label(bar, "0", Vector2(722, 13), 22, Color(0.7, 0.85, 1.0))
	_mana_rate = UiUtil.label(bar, "", Vector2(722, 35), 14, Color(0.55, 0.75, 1.0))
	bar.get_child(bar.get_child_count() - 3).tooltip_text = "Mana : sert à jouer les cartes"


func _build_top_right() -> void:
	UiUtil.panel(_root, "clock", Vector2(1341, 17), 1, 0)
	_clock_label = UiUtil.label(_root, "00:00", Vector2.ZERO, 24)
	UiUtil.anchor(_clock_label, Vector2(1390, 25), Vector2(64, 34), 1, 0)
	var pause := _texture_button("btn_pause", Vector2(1482, 17), "Pause (menu)")
	pause.pressed.connect(func(): _pause_menu.open())
	_fast_button = _texture_button("btn_fast", Vector2(1540, 17), "Accélérer (x2)")
	_fast_button.toggle_mode = true
	_fast_button.toggled.connect(_on_fast_toggled)
	var menu := _texture_button("btn_settings", Vector2(1599, 17), "Menu")
	menu.pressed.connect(func(): _pause_menu.open())

	var mm := UiUtil.panel(_root, "minimap", Vector2(1341, 79), 1, 0)
	_minimap = Minimap.new()
	_minimap.position = Vector2(17, 15)
	_minimap.size = Vector2(216, 177)
	mm.add_child(_minimap)
	for def in [[&"zoom_in", Vector2(254, 25), "Zoomer (+)"], [&"zoom_out", Vector2(254, 82), "Dézoomer (−)"],
			[&"center", Vector2(254, 140), "Centrer sur la sélection"]]:
		var b := UiUtil.hotspot(mm, Rect2(def[1], Vector2(50, 48)), def[2])
		var cmd: StringName = def[0]
		b.pressed.connect(func(): command.emit(cmd))

	var obj := UiUtil.panel(_root, "objectives", Vector2(1342, 294), 1, 0)
	obj.tooltip_text = "Conditions de victoire (GDD §1.2) — Prototype 7"
	for i in 2:
		UiUtil.pixel_icon(obj, UiUtil.tex("icon_objective"), Rect2(29, 47 + i * 34, 29, 29)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		UiUtil.label(obj, ["Détruire le château ennemi", "Vaincre le roi ennemi"][i], Vector2(68, 49 + i * 34), 18)

	_hand = HandPanel.new()
	_root.add_child(_hand)
	UiUtil.anchor(_hand, Vector2(1318, 462), Vector2(344, 188), 1, 0)
	_hand.hovered.connect(func(t): _hover_text = t)
	_hand.notify.connect(show_notice)


func _build_bottom() -> void:
	var portrait := UiUtil.panel(_root, "portrait", Vector2(9, 642), 0, 1)
	_portrait = UiUtil.pixel_icon(portrait, null, Rect2(30, 40, 226, 170))
	_portrait_name = UiUtil.label(portrait, "", Vector2(16, 214), 18, UiUtil.COLOR_GOLD)
	_portrait_name.size = Vector2(254, 30)
	_portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 4:
		UiUtil.hotspot(portrait, Rect2(269, 32 + i * 58, 55, 52), "À définir").disabled = true

	var info := UiUtil.panel(_root, "info", Vector2(354, 690), 0, 1)
	_info = UiUtil.label(info, "", Vector2(30, 34), 17)
	_info.size = Vector2(530, 166)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.clip_text = true

	_build_panel = BuildPanel.new()
	_root.add_child(_build_panel)
	UiUtil.anchor(_build_panel, Vector2(953, 683), Vector2(427, 230), 1, 1)
	_build_panel.build_requested.connect(func(d): build_requested.emit(d))
	_build_panel.hovered.connect(func(t): _hover_text = t)
	_build_panel.recruit_requested.connect(func(u): recruit_requested.emit(u))

	var cmds := CommandPanel.new()
	_root.add_child(cmds)
	UiUtil.anchor(cmds, Vector2(1391, 684), Vector2(268, 233), 1, 1)
	cmds.command.connect(func(c): command.emit(c))


func _on_fast_toggled(on: bool) -> void:
	Engine.time_scale = 2.0 if on else 1.0
	_fast_button.modulate = UiUtil.COLOR_GOLD if on else Color.WHITE


func _texture_button(name: String, pos: Vector2, tooltip: String) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = UiUtil.tex(name)
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE
	_root.add_child(b)
	UiUtil.anchor(b, pos, b.texture_normal.get_size(), 1, 0)
	return b


# --- Mise à jour ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not get_tree().paused:
		_game_time += delta
	_clock_label.text = "%02d:%02d" % [int(_game_time) / 60, int(_game_time) % 60]
	_refresh_resources()
	_refresh_selection()
	_build_panel.team = _team
	_build_panel.refresh()
	_notice_time -= delta
	_notice.visible = _notice_time > 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_pause_menu.open()


func _refresh_resources() -> void:
	if economy_system == null:
		return
	var econ := economy_system.economy(_team)
	for r in _amount_labels:
		var amount := econ.get_amount(r)
		var l: Label = _amount_labels[r]
		l.text = str(amount)
		l.tooltip_text = "%s : %d / %d" % [ResourceTypes.NAMES[r], amount, econ.capacity(r)]
		var empty_food: bool = r == ResourceTypes.FOOD and amount == 0
		l.add_theme_color_override("font_color", UiUtil.COLOR_LOSS if empty_food
				else (UiUtil.COLOR_GOLD if econ.is_full(r) else UiUtil.COLOR_TEXT))
		var rate: int = econ.last_income.get(r, 0)
		var rl: Label = _rate_labels[r]
		rl.text = "" if rate == 0 else "(%+d)" % rate
		rl.add_theme_color_override("font_color", UiUtil.COLOR_GAIN if rate > 0 else UiUtil.COLOR_LOSS)
	if card_system and not card_system.players.is_empty():
		var p := card_system.player(_team)
		_mana_label.text = "%d / %d" % [int(p.mana), int(GameConfig.MANA_MAX)]
		_mana_rate.text = "(+%.2f)" % p.mana_regen()
		_mana_label.tooltip_text = "Mana : %.1f / %d — régénération %.2f par tour" % [p.mana, int(GameConfig.MANA_MAX), p.mana_regen()]
		_hand.refresh()


func _refresh_selection() -> void:
	_selection = _selection.filter(func(s): return is_instance_valid(s) and s.is_alive())
	if _selection.is_empty():
		_portrait.texture = null
		_portrait_name.text = ""
	else:
		_portrait.texture = _selection[0].data.sprite
		_portrait_name.text = _selection[0].data.display_name + ("" if _selection.size() == 1 else "  +%d" % (_selection.size() - 1))
	if not is_instance_valid(_building):
		_building = null
	if _building and _selection.is_empty():
		_portrait.texture = _building.data.sprite
		_portrait_name.text = _building.data.display_name
	if _hover_text != "":
		_info.text = _hover_text
	elif _building and _selection.is_empty():
		_info.text = _building_info(_building)
	elif _selection.is_empty():
		_info.text = "%s\n\n%s" % [GameConfig.TEAM_NAMES[_team], HELP]
	else:
		var lines: Array[String] = []
		for s in _selection.slice(0, 7):
			lines.append("%s — %d/%d individus · %d/%d PV · %s" % [s.data.display_name, s.alive_count(),
					s.data.squad_size, s.total_hp(), s.max_total_hp(), _status(s)])
		if _selection.size() > 7:
			lines.append("… et %d autres escouades" % (_selection.size() - 7))
		_info.text = "\n".join(lines)


static func _building_info(b: Building) -> String:
	var lines := [b.data.display_name]
	if not b.is_complete:
		lines.append("En construction : %d %%" % int(100.0 * b.progress / maxf(b.work_needed(), 0.001)))
	elif not b.fed:
		lines.append("Sans nourriture : à l'arrêt")
	if not b.data.production.is_empty():
		lines.append("Production / tour : " + ResourceTypes.format(b.data.production))
	if not b.data.upkeep.is_empty():
		lines.append("Consommation / tour : " + ResourceTypes.format(b.data.upkeep))
	if not b.data.recruit_per_turn.is_empty():
		if b.queue.is_empty():
			lines.append("Aucun recrutement — onglet Recrutement pour recruter.")
		else:
			var names := b.queue.map(func(u): return u.display_name)
			lines.append("Recrutement : %s (%d %%)" % [names[0], int(b.recruit_ratio() * 100)])
			if names.size() > 1:
				lines.append("En file : " + ", ".join(names.slice(1)))
	return "\n".join(lines)


static func _status(s: Squad) -> String:
	var status: String = ["Repos", "Déplacement", "Soin" if s.data.action == UnitData.ActionType.HEAL else "Combat",
			"Construction" if s.work_target is Building else "Récolte"][s.state]
	if not s.is_fed():
		status = "À l'arrêt (sans nourriture)"
	if s.is_burning():
		status += " · Brûlure"
	return status


# --- API utilisée par la scène et le contrôleur de sélection ----------------------

func on_selection_changed(selection: Array[Squad]) -> void:
	_selection = selection.duplicate()


func on_building_selected(b: Building) -> void:
	_building = b
	if b and not b.data.recruit_per_turn.is_empty():
		_build_panel.set_tab(BuildPanel.Tab.RECRUITMENT)


func on_team_changed(team: int) -> void:
	_team = team
	if card_system and not card_system.players.is_empty():
		_hand.cards = card_system.player(team)


func set_card_system(cs: CardSystem) -> void:
	card_system = cs
	_hand.cards = cs.player(_team)


func show_notice(text: String) -> void:
	_notice.text = text
	_notice_time = NOTICE_DURATION


func on_build_mode_changed(data: BuildingData) -> void:
	if data:
		show_notice("Placer : %s — clic dans votre royaume · Échap pour annuler" % data.display_name)
	else:
		_notice_time = 0.0
