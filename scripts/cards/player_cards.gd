class_name PlayerCards
extends RefCounted
## Deck, main et mana d'un joueur (GDD §4, §7, §9).
##
## Règles appliquées :
## - Main initiale : 3 cartes ; limite normale : 3 (GDD §9).
## - Jouer une carte : payer son mana, appliquer l'effet, la carte retourne SOUS le
##   deck (ou disparaît si à usage unique), puis la main est complétée (§9).
## - Les cartes malus occupent la main ; le joueur peut les garder (carte morte) ou
##   les activer : effet appliqué, retour sous le deck, pioche (§7.2).
## - Cartes obtenues sur le terrain : ajoutées directement à la main, jamais au deck ;
##   elles disparaissent après usage (§9).
## - Bannissement : retire définitivement une carte (§9).
## - Mana : régénération naturelle automatique, identique pour les deux joueurs (§4.1),
##   modifiable par des bonus temporaires (§4.2). Payé à l'activation (§4.3).

signal changed
## Une carte demande de choisir une carte de la main (Destruction, Bannissement).
signal target_needed(card: CardData)

var team: int
var economy: PlayerEconomy
## Deck : index 0 = dessus (prochaine carte piochée).
var deck: Array[CardData] = []
var hand: Array[CardData] = []
## Cartes de la main obtenues sur le terrain (disparaissent après usage).
var field_cards: Array[CardData] = []
var hand_limit: int = GameConfig.HAND_LIMIT
var banished: Array[CardData] = []
var mana: float = 0.0
## Bonus de régénération actifs : [{multiplier, turns_left}].
var regen_boosts: Array = []
## Carte jouée en attente d'une carte cible de la main.
var pending: CardData = null


func _init(p_team: int = 0, p_economy: PlayerEconomy = null) -> void:
	team = p_team
	economy = p_economy


## Constitue le deck (mélangé) et pioche la main initiale.
func setup(cards: Array, rng: RandomNumberGenerator) -> void:
	deck.clear()
	for c in cards:
		deck.append(c)
	_shuffle(rng)
	hand.clear()
	refill()


func _shuffle(rng: RandomNumberGenerator) -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := deck[i]
		deck[i] = deck[j]
		deck[j] = tmp


# --- Mana -----------------------------------------------------------------------------

func mana_regen() -> float:
	var r := GameConfig.MANA_REGEN_PER_TURN
	for b in regen_boosts:
		r *= b.multiplier
	return r


## Un tour : régénération du mana, fin des bonus expirés.
func on_turn() -> void:
	mana = minf(GameConfig.MANA_MAX, mana + mana_regen())
	for b in regen_boosts:
		b.turns_left -= 1
	regen_boosts = regen_boosts.filter(func(b): return b.turns_left > 0)
	changed.emit()


# --- Main et deck ---------------------------------------------------------------------

func draw(count: int = 1) -> int:
	var drawn := 0
	for i in count:
		if deck.is_empty():
			break
		hand.append(deck.pop_front())
		drawn += 1
	if drawn > 0:
		changed.emit()
	return drawn


## Complète la main jusqu'à la limite.
func refill() -> void:
	draw(maxi(0, hand_limit - hand.size()))


## Nombre de cartes jouables de la main (non malus) — GDD §7.2.
func usable_count() -> int:
	return hand.filter(func(c): return c.category != CardData.Category.MALUS).size()


## Carte obtenue sur le terrain (bénédiction, malédiction, butin) : directement en main.
func add_field_card(card: CardData) -> CardData:
	var copy := card.duplicate() as CardData  # exemplaire distinct de ceux du deck
	hand.append(copy)
	field_cards.append(copy)
	changed.emit()
	return copy


func can_play(index: int) -> bool:
	if pending != null or index < 0 or index >= hand.size():
		return false
	var card := hand[index]
	if card.category == CardData.Category.HERO:
		return false  # héros : Prototype 6
	if card.needs_hand_target() and _targets_for(card, index).is_empty():
		return false
	return mana >= card.mana_cost


## Raison pour laquelle la carte ne peut pas être jouée ("" si possible).
func play_error(index: int) -> String:
	if pending != null:
		return "Choisissez d'abord la carte cible."
	if index < 0 or index >= hand.size():
		return ""
	var card := hand[index]
	if card.category == CardData.Category.HERO:
		return "Les héros arrivent au Prototype 6."
	if card.needs_hand_target() and _targets_for(card, index).is_empty():
		return "Aucune carte à cibler dans la main."
	if mana < card.mana_cost:
		return "Mana insuffisant (%d / %d)." % [int(mana), card.mana_cost]
	return ""


## Joue la carte `index`. Si elle demande une cible, attend `choose_target`.
func play(index: int) -> bool:
	if not can_play(index):
		return false
	var card := hand[index]
	mana -= card.mana_cost
	hand.remove_at(index)
	if card.needs_hand_target():
		pending = card
		changed.emit()
		target_needed.emit(card)
		return true
	_apply(card)
	_finish(card)
	return true


## Cible choisie pour la carte en attente (index dans la main).
func choose_target(index: int) -> bool:
	if pending == null or index < 0 or index >= hand.size():
		return false
	var card := pending
	var target := hand[index]
	if card.effect == CardData.Effect.BANISH_MALUS and target.category != CardData.Category.MALUS:
		return false
	hand.remove_at(index)
	if card.effect == CardData.Effect.BANISH_MALUS:
		_banish(target)
	else:
		_put_under_deck(target)  # Destruction : la carte quitte la main
	pending = null
	_finish(card)
	return true


## Annule une carte en attente de cible : elle revient en main, mana rendu.
func cancel_pending() -> void:
	if pending == null:
		return
	mana += pending.mana_cost
	hand.append(pending)
	pending = null
	changed.emit()


func _targets_for(card: CardData, played_index: int) -> Array:
	var out := []
	for i in hand.size():
		if i == played_index:
			continue
		if card.effect == CardData.Effect.BANISH_MALUS and hand[i].category != CardData.Category.MALUS:
			continue
		out.append(i)
	return out


func _apply(card: CardData) -> void:
	var p := card.params
	match card.effect:
		CardData.Effect.GAIN_RESOURCES:
			if economy:
				economy.add_all(p.get("resources", {}))
		CardData.Effect.MANA_REGEN_BOOST:
			regen_boosts.append({"multiplier": float(p.get("multiplier", 1.0)), "turns_left": int(p.get("turns", 1))})
		CardData.Effect.HAND_LIMIT_UP:
			hand_limit += int(p.get("amount", 1))
		CardData.Effect.DRAW_CARDS:
			draw(int(p.get("amount", 1)))


## Après activation : la carte retourne sous le deck (ou disparaît), puis on complète la main.
func _finish(card: CardData) -> void:
	if card in field_cards:
		field_cards.erase(card)  # carte du terrain : jamais ajoutée au deck
	elif not card.single_use:
		_put_under_deck(card)
	refill()
	changed.emit()


func _put_under_deck(card: CardData) -> void:
	if card in field_cards:
		field_cards.erase(card)
		return
	deck.append(card)


func _banish(card: CardData) -> void:
	if card in field_cards:
		field_cards.erase(card)
	banished.append(card)
