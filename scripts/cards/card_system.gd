class_name CardSystem
extends Node
## Cartes des deux joueurs (GDD §9) :
## - deck de 20 cartes : 10 bonus choisis par le joueur, 5 malus choisis par
##   l'adversaire, 5 neutres tirés au hasard (les mêmes pour les deux joueurs) ;
## - régénération du mana à chaque tour de l'économie.
## [PROVISOIRE] Tant qu'il n'y a pas d'écran de constitution du deck, les deux
## joueurs reçoivent le deck de base (GDD §10 : même deck pour le premier prototype).

## Deck de base [PROVISOIRE] : {id de carte: nombre}.
const DEFAULT_BONUS := {&"royal_treasure": 5, &"mana_surge": 5}
const DEFAULT_MALUS := {&"malus_placeholder": 5}

var players: Array[PlayerCards] = []
var rng := RandomNumberGenerator.new()


## `economy` : pour les effets de ressources ; `seed` : tirage des neutres et mélange.
func setup(economy: EconomySystem, seed: int = 0) -> void:
	rng.seed = seed
	players.clear()
	var neutrals := random_neutrals(GameConfig.DECK_NEUTRAL)
	for team in 2:
		var p := PlayerCards.new(team, economy.economy(team) if economy else null)
		var deck := expand(DEFAULT_BONUS) + expand(DEFAULT_MALUS) + neutrals
		p.setup(deck, rng)
		players.append(p)
	if economy and not economy.turn_processed.is_connected(on_turn):
		economy.turn_processed.connect(on_turn)


func player(team: int) -> PlayerCards:
	return players[team]


func on_turn() -> void:
	for p in players:
		p.on_turn()


## {id: nombre} -> liste de cartes.
static func expand(counts: Dictionary) -> Array:
	var out := []
	for id in counts:
		var card := CardDatabase.get_card(id)
		if card == null:
			push_error("Carte inconnue : %s" % id)
			continue
		for i in counts[id]:
			out.append(card)
	return out


## `count` cartes neutres tirées au hasard (identiques pour les deux joueurs).
func random_neutrals(count: int) -> Array:
	var pool := CardDatabase.of_category(CardData.Category.NEUTRAL)
	pool.sort_custom(func(a, b): return a.id < b.id)
	var out := []
	if pool.is_empty():
		return out
	for i in count:
		out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out
