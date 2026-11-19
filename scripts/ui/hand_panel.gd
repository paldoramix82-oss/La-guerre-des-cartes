class_name HandPanel
extends TextureRect
## Panneau « Main de cartes » de la maquette : les cartes de la main du joueur.
## Clic sur une carte : la jouer. Pour Destruction / Bannissement, clic ensuite
## sur la carte cible (Échap ou bouton Annuler pour renoncer).

signal hovered(text: String)
signal notify(text: String)

## Zone des cartes dans l'image du panneau.
const AREA := Rect2(27, 57, 290, 116)
const CARD_MAX_WIDTH := 93.0
const GAP := 4.0
const CATEGORY_COLORS := {
	CardData.Category.BONUS: Color(0.85, 0.65, 0.2),
	CardData.Category.MALUS: Color(0.6, 0.15, 0.25),
	CardData.Category.NEUTRAL: Color(0.25, 0.45, 0.75),
	CardData.Category.HERO: Color(0.45, 0.3, 0.7),
}
const CATEGORY_NAMES := {
	CardData.Category.BONUS: "Bonus",
	CardData.Category.MALUS: "Malus",
	CardData.Category.NEUTRAL: "Neutre",
	CardData.Category.HERO: "Héros",
}

var cards: PlayerCards:
	set(value):
		if cards and cards.changed.is_connected(_rebuild):
			cards.changed.disconnect(_rebuild)
		cards = value
		if cards:
			cards.changed.connect(_rebuild)
		_rebuild()

var _views: Array[Control] = []
var _title: Label


func _ready() -> void:
	texture = UiUtil.tex("hand")
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(event: InputEvent) -> void:
	if cards and cards.pending and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cards.cancel_pending()
		notify.emit("Carte annulée.")
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	for v in _views:
		v.queue_free()
	_views.clear()
	if cards == null:
		return
	var n := cards.hand.size()
	var w := minf(CARD_MAX_WIDTH, (AREA.size.x - GAP * (n - 1)) / maxf(n, 1))
	var total := w * n + GAP * (n - 1)
	var x0 := AREA.position.x + (AREA.size.x - total) * 0.5
	for i in n:
		var v := _CardView.new()
		v.card = cards.hand[i]
		v.panel = self
		v.index = i
		v.position = Vector2(x0 + i * (w + GAP), AREA.position.y)
		v.size = Vector2(w, AREA.size.y)
		add_child(v)
		_views.append(v)
	queue_redraw()


func refresh() -> void:
	for v in _views:
		v.queue_redraw()


func _on_card_clicked(index: int) -> void:
	if cards.pending:
		if not cards.choose_target(index):
			notify.emit("Choisissez une carte valide (Bannissement : une carte malus).")
		return
	var err := cards.play_error(index)
	if err != "":
		notify.emit(err)
		return
	var card := cards.hand[index]
	cards.play(index)
	if cards.pending:
		notify.emit("%s : cliquez sur la carte à %s." % [card.display_name,
				"bannir" if card.effect == CardData.Effect.BANISH_MALUS else "défausser"])
	else:
		notify.emit("%s jouée." % card.display_name)


func describe(card: CardData) -> String:
	var text := "%s — %s · %d mana\n%s" % [card.display_name, CATEGORY_NAMES[card.category], card.mana_cost, card.description]
	if card.single_use:
		text += "\nUsage unique."
	if cards and card in cards.field_cards:
		text += "\nCarte obtenue sur le terrain : disparaît après usage."
	return text


## Une carte de la main, dessinée (fond selon la catégorie, icône, coût, nom).
class _CardView:
	extends Control
	var card: CardData
	var panel: HandPanel
	var index := 0
	var _hover := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func _on_enter() -> void:
		_hover = true
		queue_redraw()
		panel.hovered.emit(panel.describe(card))

	func _on_exit() -> void:
		_hover = false
		queue_redraw()
		panel.hovered.emit("")

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			panel._on_card_clicked(index)
			accept_event()

	func _draw() -> void:
		var playable := panel.cards != null and (panel.cards.pending != null or panel.cards.can_play(index))
		var base: Color = HandPanel.CATEGORY_COLORS[card.category]
		var r := Rect2(Vector2.ZERO, size)
		var lift := Vector2(0, -6) if _hover else Vector2.ZERO
		r.position += lift
		draw_rect(r, base.darkened(0.55))
		draw_rect(r.grow(-3), base.darkened(0.2) if playable else base.darkened(0.6))
		draw_rect(r, UiUtil.COLOR_GOLD if _hover else base.lightened(0.3), false, 2.0)
		if card.icon:
			var s := minf(size.x - 20, 48.0)
			var ir := Rect2(r.position + Vector2((size.x - s) * 0.5, 22), Vector2(s, s))
			draw_texture_rect(card.icon, ir, false, Color(1, 1, 1, 1.0 if playable else 0.5))
		var font: Font = load(UiUtil.FONT_BOLD)
		# Coût en mana (pastille bleue).
		draw_circle(r.position + Vector2(13, 13), 10, Color(0.15, 0.35, 0.85))
		draw_string(font, r.position + Vector2(3, 18), str(card.mana_cost), HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color.WHITE)
		# Nom (sur deux lignes si besoin).
		draw_multiline_string(font, r.position + Vector2(4, size.y - 34), card.display_name, HORIZONTAL_ALIGNMENT_CENTER,
				size.x - 8, 11, 2, UiUtil.COLOR_TEXT)
