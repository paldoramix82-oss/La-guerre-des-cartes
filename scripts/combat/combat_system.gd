class_name CombatSystem
extends RefCounted
## Règles de combat, indépendantes du rendu et des contrôles (GDD §5).
##
## Règles appliquées :
## - PV et dégâts sont individuels : à chaque attaque, CHAQUE individu vivant de
##   l'escouade attaquante porte un coup de `damage` (4 guerriers -> 40 dégâts).
## - Chaque coup touche un individu de l'escouade ciblée ; un individu à 0 PV est
##   retiré ; l'escouade disparaît quand elle n'a plus d'individus.
##
## Choix [PROVISOIRES] (non précisés par le GDD, cf. docs/PROTOTYPE_1.md) :
## - Distance sur la grille = distance de Chebyshev (les diagonales comptent 1).
## - Les coups touchent les individus dans l'ordre (le premier vivant d'abord) ;
##   les dégâts excédentaires d'un coup ne sont pas reportés sur l'individu suivant.


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
	var hit: Array[Squad] = []
	var hits := attacker.alive_count()
	if hits == 0:
		return hit
	if attacker.data.attack_pattern == UnitData.AttackPattern.SINGLE:
		hit.append(target)
	else:
		var cells := affected_cells(attacker.data, attacker.get_cell(), target.get_cell())
		for s in all_squads:
			if is_instance_valid(s) and s is Squad and s.is_alive() \
					and s.team != attacker.team and s.get_cell() in cells:
				hit.append(s)
	for s in hit:
		s.take_hits(hits, attacker.data.damage)
	return hit
