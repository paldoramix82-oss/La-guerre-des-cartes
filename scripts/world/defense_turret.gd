class_name DefenseTurret
extends RefCounted
## Tir automatique d'une défense (Tour Archer, Canon, Cabane Garde, Mortier) —
## valeurs du document de l'auteur (data/buildings/*.tres) :
## - vise l'individu hostile (autre joueur ou monstre) le plus proche, à portée
##   (entre `min_range` et `attack_range` cases) ;
## - Cabane Garde : `occupants` gardes tirent chacun (2 x 10 dégâts) ;
## - Mortier : zone de `zone_size` cases alignées à partir de la cible ;
## - ne tire que si la défense est terminée et nourrie.
## [PROVISOIRE] Intervalle de tir : `attack_interval` (non défini par l'auteur).

var building: Building
var cooldown := 0.0


func _init(b: Building) -> void:
	building = b


func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if cooldown > 0.0 or not building.is_inside_tree():
		return
	var target := find_target()
	if target == null:
		return
	fire(target)
	cooldown = building.data.attack_interval


func in_range(cell: Vector2i) -> bool:
	var d := CombatSystem.grid_distance(building.cell, cell)
	return d >= building.data.min_range and d <= building.data.attack_range


func find_target() -> Individual:
	var best: Individual = null
	var best_d := 1 << 30
	for n in building.get_tree().get_nodes_in_group(Individual.GROUP):
		var o := n as Individual
		if o == null or not o.is_alive() or o.team == building.team or o.squad.sheltered:
			continue
		var c := o.get_cell()
		if not in_range(c):
			continue
		var d := CombatSystem.grid_distance(building.cell, c)
		if d < best_d:
			best = o
			best_d = d
	return best


## Individus touchés par un tir sur `target`.
func affected(target: Individual) -> Array[Individual]:
	var out: Array[Individual] = []
	var data := building.data
	if data.zone_size <= 1:
		out.append(target)
		return out
	var d := target.get_cell() - building.cell
	var dir := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
	var cells: Array[Vector2i] = []
	for i in data.zone_size:
		cells.append(target.get_cell() + dir * i)
	for n in building.get_tree().get_nodes_in_group(Individual.GROUP):
		var o := n as Individual
		if o and o.is_alive() and o.team != building.team and not o.squad.sheltered and o.get_cell() in cells:
			out.append(o)
	return out


func fire(target: Individual) -> void:
	var data := building.data
	var from := building.position + Vector2(0, -10)
	if data.projectile:
		Effects.projectile(building, from, target.position, data.projectile, data.projectile_color, data.projectile_angle)
	for o in affected(target):
		for i in maxi(data.occupants, 1):
			if not is_instance_valid(o) or not o.is_alive():
				break
			o.last_attacker_team = building.team
			o.take_damage(data.damage)
