class_name Deposit
extends MapObject
## Gisement neutre (arbre, baies). Les ouvriers adjacents
## récoltent sur place `data.harvest_per_turn` par tour chacun,
## versé directement au stock de leur joueur. Le gisement s'épuise puis disparaît.

signal depleted(deposit: Deposit)

var data: DepositData
var remaining: int = 0
var economy_system: EconomySystem
## Récolte en cours (fraction de tour), par ouvrier.
var _progress: Dictionary = {}


func setup(p_data: DepositData, p_map: GameMap, p_cell: Vector2i, p_economy: EconomySystem) -> Deposit:
	data = p_data
	remaining = data.amount
	economy_system = p_economy
	name = "%s_%d_%d" % [data.id, p_cell.x, p_cell.y]
	place_on(p_map, p_cell)
	return self


func is_alive() -> bool:
	return remaining > 0


func can_be_worked_by(squad: Squad) -> bool:
	return is_alive() and squad.data.is_worker


func work(worker: Individual, delta: float) -> bool:
	if not is_alive():
		return false
	var econ := economy_system.economy(worker.team)
	if econ.is_full(data.resource):
		return true  # stock plein : l'ouvrier attend
	var p: float = _progress.get(worker, 0.0) + delta
	if p >= GameConfig.SECONDS_PER_TURN:
		p -= GameConfig.SECONDS_PER_TURN
		var amount := mini(data.harvest_per_turn, remaining)
		remaining -= econ.add(data.resource, amount)
		queue_redraw()
		if remaining <= 0:
			depleted.emit(self)
			remove()
			return false
	_progress[worker] = p
	return true


func _draw() -> void:
	_draw_sprite(data.sprite)
	# Jauge de quantité restante.
	var half := GameConfig.TILE_SIZE * 0.5
	var bar := Rect2(Vector2(-half + 6, half - 3), Vector2(GameConfig.TILE_SIZE - 12, 3))
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(remaining) / data.amount, bar.size.y)), Color(1, 0.85, 0.3))
