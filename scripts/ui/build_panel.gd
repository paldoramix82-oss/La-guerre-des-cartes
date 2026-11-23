class_name BuildPanel
extends TextureRect
## Panneau à onglets de la maquette : Construction / Recrutement / Améliorations,
## avec une grille de 8 cases.
## - Construction : bâtiments constructibles (clic -> mode construction).
## - Recrutement : unités et leur coût (le recrutement arrive au Prototype 3).
## - Améliorations : pas encore définies.

signal build_requested(data: BuildingData)
signal recruit_requested(unit: UnitData)
signal exploit_requested(mine: MineSite)
## Survol d'une case : texte d'information (vide quand la souris sort).
signal hovered(text: String)

enum Tab { CONSTRUCTION, RECRUITMENT, UPGRADES }

const TAB_NAMES := ["Construction", "Recrutement", "Améliorations"]
const TAB_X := [14, 139, 264]
const TAB_SIZE := Vector2(120, 42)
const SLOT_X := [25, 110, 193, 276]
const SLOT_Y := [49, 133]
const SLOT_SIZE := Vector2(77, 77)

var economy_system: EconomySystem
## Mine choisie à exploiter : l'onglet Construction ne propose alors que son exploitation.
var mine: MineSite = null
var team := 0
var tab: Tab = Tab.CONSTRUCTION
## Page affichée (8 cases par page) ; flèches de la maquette pour changer de page.
var page := 0
var _all_items: Array = []
var _tab_buttons: Array[TextureButton] = []
var _slots: Array[Button] = []
## Contenu de chaque case : BuildingData, UnitData ou null.
var _slot_items: Array = []


func _ready() -> void:
	texture = UiUtil.tex("tabs_panel")
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in 3:
		var b := TextureButton.new()
		b.position = Vector2(TAB_X[i], 1)
		b.size = TAB_SIZE
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_tab.bind(i))
		add_child(b)
		var l := UiUtil.label(b, TAB_NAMES[i], Vector2.ZERO, 17)
		l.size = TAB_SIZE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tab_buttons.append(b)
	for row in 2:
		for col in 4:
			var s := UiUtil.hotspot(self, Rect2(Vector2(SLOT_X[col], SLOT_Y[row]), SLOT_SIZE), "")
			s.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			s.expand_icon = true
			s.add_theme_constant_override("icon_max_width", 44)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.add_theme_font_override("font", load(UiUtil.FONT_BOLD))
			s.add_theme_font_size_override("font_size", 12)
			s.add_theme_color_override("font_color", UiUtil.COLOR_TEXT)
			s.add_theme_color_override("font_disabled_color", Color(0.6, 0.55, 0.6))
			var idx := _slots.size()
			s.pressed.connect(_on_slot_pressed.bind(idx))
			s.mouse_entered.connect(func(): hovered.emit(_describe(idx)))
			s.mouse_exited.connect(func(): hovered.emit(""))
			_slots.append(s)
	# Flèches de défilement de la maquette.
	UiUtil.hotspot(self, Rect2(383, 52, 26, 30), "Page précédente").pressed.connect(func(): _scroll(-1))
	UiUtil.hotspot(self, Rect2(383, 176, 26, 30), "Page suivante").pressed.connect(func(): _scroll(1))
	set_tab(Tab.CONSTRUCTION)


func _scroll(dir: int) -> void:
	var pages := maxi(1, ceili(_all_items.size() / float(_slots.size())))
	page = clampi(page + dir, 0, pages - 1)
	_show_page()


func set_mine(m: MineSite) -> void:
	mine = m
	set_tab(Tab.CONSTRUCTION)


func set_tab(t: int) -> void:
	tab = t as Tab
	for i in 3:
		_tab_buttons[i].texture_normal = UiUtil.tex("tab_active" if i == t else "tab_inactive")
		# Libellé foncé sur l'onglet doré (comme la maquette), clair sinon.
		var l: Label = _tab_buttons[i].get_child(0)
		l.add_theme_color_override("font_color", Color(0.16, 0.09, 0.03) if i == t else UiUtil.COLOR_TEXT)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0) if i == t else Color(0, 0, 0, 0.7))
	_slot_items.clear()
	match tab:
		Tab.CONSTRUCTION when is_instance_valid(mine) and mine.needs_exploitation():
			_slot_items = [mine.data]
		Tab.CONSTRUCTION:
			var list := BuildingDatabase.load_all().values().filter(func(b): return b.player_buildable)
			list.sort_custom(func(a, b): return [a.category, a.display_name] < [b.category, b.display_name])
			_slot_items = list
		Tab.RECRUITMENT:
			var units := UnitDatabase.load_all().values().filter(func(u): return not u.cost.is_empty())
			units.sort_custom(func(a, b): return a.display_name < b.display_name)
			_slot_items = units
	_all_items = _slot_items
	page = 0
	_show_page()


func _show_page() -> void:
	var start := page * _slots.size()
	_slot_items = _all_items.slice(start, start + _slots.size())
	for i in _slots.size():
		var item = _slot_items[i] if i < _slot_items.size() else null
		_slots[i].visible = item != null
		if item:
			_slots[i].icon = item.sprite
			_slots[i].text = "Exploiter" if item is BuildingData and item.id == MineSite.DATA_ID else item.display_name
	refresh()


## Met à jour la disponibilité des cases (ressources).
func refresh() -> void:
	if economy_system == null:
		return
	var econ := economy_system.economy(team)
	for i in mini(_slots.size(), _slot_items.size()):
		var item = _slot_items[i]
		if item is BuildingData and item.id == MineSite.DATA_ID:
			_slots[i].disabled = not is_instance_valid(mine) or economy_system.exploit_error(mine, team) != ""
		elif item is BuildingData:
			_slots[i].disabled = not econ.can_afford(item.cost)
		else:
			_slots[i].disabled = economy_system.recruit_error(item, team) != ""


func _on_slot_pressed(idx: int) -> void:
	if idx >= _slot_items.size():
		return
	if _slot_items[idx] is BuildingData and _slot_items[idx].id == MineSite.DATA_ID:
		exploit_requested.emit(mine)
	elif _slot_items[idx] is BuildingData:
		build_requested.emit(_slot_items[idx])
	else:
		recruit_requested.emit(_slot_items[idx])


func _describe(idx: int) -> String:
	if idx >= _slot_items.size():
		return ""
	var item = _slot_items[idx]
	if item is BuildingData:
		var d: BuildingData = item
		var lines := ["%s — %s" % ["Exploiter la mine" if d.id == MineSite.DATA_ID else d.display_name, ResourceTypes.format(d.cost)]]
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
	var u: UnitData = item
	var effect := "soin %d" % u.heal_amount if u.action == UnitData.ActionType.HEAL else "%d dégâts" % u.damage
	var text := "%s — %s\nEscouade de %d · %d PV · %s · portée %d · déplacement %s\nConsommation : %s / tour" % [
		u.display_name, ResourceTypes.format(u.cost), u.squad_size, u.hp, effect, u.attack_range,
		str(u.move_speed), ResourceTypes.format(u.upkeep_for(u.squad_size))]
	if economy_system:
		var err := economy_system.recruit_error(u, team)
		if err != "":
			text += "\n" + err
	return text
