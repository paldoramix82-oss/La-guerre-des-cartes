class_name CombatSystem
extends RefCounted
## Règles de combat, indépendantes du rendu et des contrôles (GDD §5).
##
## Règles appliquées :
## - PV et dégâts sont individuels : à chaque attaque, CHAQUE individu vivant de
##   l'escouade attaquante porte un coup de `damage` (4 guerriers -> 40 dégâts).
## - Chaque coup touche un individu de l'escouade ciblée ; un individu à 0 PV est
##   retiré ; l'escouade disparaît quand elle n'a plus d'individus.
## - Brûlure (Mage) : chaque escouade touchée subit ensuite `burn_damage` dégâts
##   par tour pendant `burn_turns` tours.
## - Soin (Soigneur) : chaque individu soignant rend `heal_amount` PV aux escouades
##   alliées de sa zone. Les individus morts ne sont pas ressuscités (GDD §12.4).
##
## Choix [PROVISOIRES] (non précisés par le GDD, cf. docs/PROTOTYPE_1.md) :
## - Distance sur la grille = distance de Chebyshev (les diagonales comptent 1).
## - Les coups touchent les individus dans l'ordre (le premier vivant d'abord) ;
##   les dégâts excédentaires d'un coup ne sont pas reportés sur l'individu suivant.
## - Brûlure : un coup de `burn_damage` par individu attaquant et par tour ; une
##   nouvelle brûlure du même type d'unité remplace la précédente (pas de cumul).
## - Soin : chaque soin va à l'individu le plus blessé, sans dépasser ses PV max.


static func can_target(actor: Squad, other: Squad) -> bool:
	if other == null or other == actor or not other.is_alive():
		return false
	if actor.data.action == UnitData.ActionType.HEAL:
		return other.team == actor.team
	return other.team != actor.team and actor.data.damage > 0


static func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func in_range(attacker: Squad, target: Squad) -> bool:
	return grid_distance(attacker.get_cell(), target.get_cell()) <= attacker.data.attack_range


## Cases touchées par une attaque selon la géométrie de l'unité (GDD §5.2).
static func affected_cells(data: UnitData, attacker_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match data.attack_pattern:
		UnitData.AttackPattern.SINGLE:
			cells.append(target_cell)
		UnitData.AttackPattern.CIRCLE:
			# Cavalier "Cercle 1" : toutes les cases autour de l'attaquant.
			for dy in range(-data.zone_size, data.zone_size + 1):
				for dx in range(-data.zone_size, data.zone_size + 1):
					cells.append(attacker_cell + Vector2i(dx, dy))
		UnitData.AttackPattern.LINE:
			# Mage "Zone 2" : 2 cases horizontales OU verticales, à partir de la cible,
			# dans l'axe dominant attaquant -> cible.
			var d := target_cell - attacker_cell
			var dir := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
			if dir == Vector2i.ZERO:
				dir = Vector2i.RIGHT
			for i in data.zone_size:
				cells.append(target_cell + dir * i)
	return cells


## Résout une attaque de `attacker` sur `target`. `all_squads` sert aux attaques de zone.
## Retourne la liste des escouades touchées.
static func perform_attack(attacker: Squad, target: Squad, all_squads: Array) -> Array[Squad]:
	var hits := attacker.alive_count()
	var hit := _squads_in_zone(attacker, target, all_squads, false)
	for s in hit:
		if attacker.data.burn_turns > 0 and attacker.data.burn_damage > 0:
			s.apply_burn(attacker.data.id, hits, attacker.data.burn_damage, attacker.data.burn_turns)
		s.take_hits(hits, attacker.data.damage)
	return hit


## Résout un soin de `healer` centré sur l'alliée `target`. Retourne les escouades soignées.
static func perform_heal(healer: Squad, target: Squad, all_squads: Array) -> Array[Squad]:
	var healed := _squads_in_zone(healer, target, all_squads, true)
	for s in healed:
		s.heal(healer.alive_count(), healer.data.heal_amount)
	return healed


## Escouades concernées par l'action : alliées (`allies`) ou ennemies de `actor`.
static func _squads_in_zone(actor: Squad, target: Squad, all_squads: Array, allies: bool) -> Array[Squad]:
	var result: Array[Squad] = []
	if actor.alive_count() == 0:
		return result
	if actor.data.attack_pattern == UnitData.AttackPattern.SINGLE:
		result.append(target)
		return result
	var cells := affected_cells(actor.data, actor.get_cell(), target.get_cell())
	for s in all_squads:
		if is_instance_valid(s) and s is Squad and s.is_alive() \
				and (s.team == actor.team) == allies and s.get_cell() in cells:
			result.append(s)
	return result
