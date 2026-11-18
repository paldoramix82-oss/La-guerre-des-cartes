class_name PlayerEconomy
extends RefCounted
## Stock de ressources d'un joueur (GDD §3) : quantités, capacités de stockage,
## paiements. Ne connaît ni la carte ni les bâtiments : EconomySystem lui fournit
## la capacité ajoutée par les bâtiments terminés.

signal changed

var team: int
var amounts: Dictionary = {}
## Capacité ajoutée par les bâtiments de stockage terminés.
var extra_storage: Dictionary = {}


func _init(p_team: int = 0, start: Dictionary = GameConfig.STARTING_RESOURCES) -> void:
	team = p_team
	for r in ResourceTypes.ALL:
		amounts[r] = int(start.get(r, 0))


func get_amount(r: StringName) -> int:
	return amounts.get(r, 0)


func capacity(r: StringName) -> int:
	return int(GameConfig.BASE_STORAGE.get(r, 0)) + int(extra_storage.get(r, 0))


func can_afford(cost: Dictionary) -> bool:
	for r in cost:
		if get_amount(r) < cost[r]:
			return false
	return true


## Paie `cost` si possible. Retourne true si payé.
func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for r in cost:
		amounts[r] -= cost[r]
	changed.emit()
	return true


## Ajoute `amount` de `r` dans la limite de la capacité. Retourne la quantité stockée.
func add(r: StringName, amount: int) -> int:
	var stored := clampi(capacity(r) - get_amount(r), 0, amount)
	if stored > 0:
		amounts[r] += stored
		changed.emit()
	return stored


func add_all(res: Dictionary) -> void:
	for r in res:
		add(r, res[r])


func is_full(r: StringName) -> bool:
	return get_amount(r) >= capacity(r)


func set_extra_storage(storage: Dictionary) -> void:
	extra_storage = storage
	# Au-delà de la capacité (bâtiment de stockage perdu), l'excédent est perdu.
	for r in ResourceTypes.ALL:
		amounts[r] = mini(amounts[r], capacity(r))
	changed.emit()
