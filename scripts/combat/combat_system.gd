class_name CombatSystem
extends RefCounted
## Règles de combat, indépendantes du rendu et des contrôles (GDD §5).
##
## Chaque individu occupe sa propre case et agit depuis celle-ci :
## - Attaque : l'individu frappe l'individu ennemi visé (`damage`), ou tous les
##   individus ennemis des cases de sa zone (Cavalier : cercle, Mage : ligne).
##   4 guerriers à portée = 4 coups de 10 = 40 dégâts.
## - Un individu à 0 PV est retiré ; l'escouade disparaît quand elle n'a plus d'individus.
## - Chaque individu attaque toutes les `attack_interval` secondes.
## - Brûlure (Mage) : chaque individu touché subit ensuite `burn_damage` dégâts par
##   seconde pendant `burn_seconds` s ; relancée par le même Mage, cumulée entre Mages.
## - Soin (Soigneur) : chaque individu allié des cases de la zone récupère
##   `heal_amount` PV, sans dépasser ses PV max. Pas de résurrection (GDD §12.4).
##
## Choix [PROVISOIRES] (non précisés par le GDD, cf. docs/PROTOTYPE_1.md) :
## - Distance sur la grille = distance de Chebyshev (les diagonales comptent 1).
## - Chaque individu vise l'individu valide le plus proche de l'escouade ciblée.


static func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## L'individu `actor` peut-il atteindre l'individu `other` depuis sa case ?
static func in_range(actor: Individual, other: Individual) -> bool:
	return grid_distance(actor.get_cell(), other.get_cell()) <= actor.data.attack_range


## L'escouade `actor` peut-elle viser l'escouade `other` ?
## `other` n'est pas typé : il peut s'agir d'une escouade détruite (objet libéré).
static func can_target(actor: Squad, other) -> bool:
	if not is_instance_valid(other) or not (other is Squad) or other == actor or not other.is_alive():
		return false
	if actor.data.action == UnitData.ActionType.HEAL:
		return other.team == actor.team
	return other.team != actor.team and actor.data.damage > 0


## Cases touchées par une action selon la géométrie de l'unité (GDD §5.2).
static func affected_cells(data: UnitData, actor_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match data.attack_pattern:
		UnitData.AttackPattern.SINGLE:
			cells.append(target_cell)
		UnitData.AttackPattern.CIRCLE:
			# Cavalier "Cercle 1" : toutes les cases autour de l'individu.
			for dy in range(-data.zone_size, data.zone_size + 1):
				for dx in range(-data.zone_size, data.zone_size + 1):
					if dx != 0 or dy != 0:
						cells.append(actor_cell + Vector2i(dx, dy))
		UnitData.AttackPattern.LINE:
			# Mage "Zone 2" : 2 cases horizontales OU verticales, à partir de la cible,
			# dans l'axe dominant individu -> cible.
			var d := target_cell - actor_cell
			var dir := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
			if dir == Vector2i.ZERO:
				dir = Vector2i.RIGHT
			for i in data.zone_size:
				cells.append(target_cell + dir * i)
	return cells


## Individus concernés par l'action de `actor` visant `target`.
static func affected_individuals(actor: Individual, target: Individual) -> Array[Individual]:
	var result: Array[Individual] = []
	var allies := actor.data.action == UnitData.ActionType.HEAL
	if actor.data.attack_pattern == UnitData.AttackPattern.SINGLE:
		result.append(target)
		return result
	var cells := affected_cells(actor.data, actor.get_cell(), target.get_cell())
	for node in actor.get_tree().get_nodes_in_group(Individual.GROUP):
		var o := node as Individual
		if o and o.is_alive() and not o.squad.sheltered and (o.team == actor.team) == allies and o.get_cell() in cells:
			result.append(o)
	return result


## Résout l'action (attaque ou soin) de `actor` sur `target`. Retourne les individus touchés.
static func perform_action(actor: Individual, target: Individual) -> Array[Individual]:
	var touched := affected_individuals(actor, target)
	var d := actor.data
	for o in touched:
		if d.action == UnitData.ActionType.HEAL:
			o.heal(d.heal_amount)
		else:
			o.last_attacker_team = actor.team
			if d.burn_seconds > 0.0 and d.burn_damage > 0:
				o.apply_burn(actor.get_instance_id(), d.burn_damage, d.burn_seconds, actor.team)
			o.take_damage(d.damage)
	return touched
