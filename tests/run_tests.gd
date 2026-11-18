extends SceneTree
## Tests headless du Prototype 1.
## Lancement : godot --headless --path . -s res://tests/run_tests.gd

var _failures := 0
var _checks := 0
var map: GameMap
var _started := false


## Les tests tournent à la première frame, quand la racine est dans l'arbre.
func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run_all()
	return false


func _run_all() -> void:
	map = GameMap.new()
	root.add_child(map)
	if map.tiles.is_empty():
		map.generate_placeholder_layout()
	_test_all_scripts_compile()
	_test_unit_data_matches_gdd()
	_test_one_individual_per_cell()
	_test_squad_totals()
	_test_individual_damage_and_removal()
	_test_squad_destruction()
	_test_range_per_individual()
	_test_area_patterns()
	_test_cavalier_circle_hits_multiple()
	_test_mage_line_hits_two_individuals()
	_test_pathfinding_avoids_water()
	_test_movement_speed()
	_test_group_move_keeps_one_per_cell()
	_test_attack_order_chases_and_kills()
	_test_mage_burn()
	_test_burn_refresh()
	_test_heal()
	_test_healer_auto_heals_and_never_attacks()
	_test_full_battle_invariants()
	_test_one_button_controls()
	_test_dead_target_does_not_crash()
	print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("ÉCHEC : ", msg)


func _clear_squads() -> void:
	for s in get_nodes_in_group(Squad.GROUP):
		s.remove_from_group(Squad.GROUP)
		s.free()
	map._occupants.clear()


## Crée une escouade autour de `cell`, ou exactement sur `cells`.
func spawn(id: StringName, team: int, cell: Vector2i, cells: Array = []) -> Squad:
	var s := Squad.new()
	root.add_child(s)
	s.setup(UnitDatabase.get_unit(id), team, map, cell, cells)
	return s


func _run_ticks(squads: Array, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		for s in squads:
			if is_instance_valid(s):
				s.tick(0.05)
		_flush_deleted()
		t += 0.05


## Comme en fin de frame dans le jeu : libère réellement les nœuds en attente de suppression
## (queue_free). Sans cela, les tests ne voient jamais d'objets libérés.
func _flush_deleted() -> void:
	for n in get_nodes_in_group(Squad.GROUP) + get_nodes_in_group(Individual.GROUP):
		if is_instance_valid(n) and n.is_queued_for_deletion():
			n.free()
	for s in get_nodes_in_group(Squad.GROUP):
		for c in s.get_children():
			if c.is_queued_for_deletion():
				c.free()


## Toutes les cases occupées par des individus vivants immobiles sont distinctes.
func _cells_unique() -> bool:
	var seen := {}
	for n in get_nodes_in_group(Individual.GROUP):
		var m := n as Individual
		if m.is_alive() and not m.is_moving():
			var c := m.get_cell()
			if seen.has(c):
				return false
			seen[c] = true
	return true


# --- Tests ------------------------------------------------------------------

## Charge tous les scripts et scènes du projet : détecte les erreurs de compilation.
func _test_all_scripts_compile() -> void:
	for dir_path in ["res://scripts", "res://scenes"]:
		for file in _list_files(dir_path):
			if file.ends_with(".gd"):
				var script: GDScript = load(file)
				check(script != null and script.can_instantiate(), "compile : %s" % file)
			elif file.ends_with(".tscn"):
				var scene: PackedScene = load(file)
				check(scene != null and scene.can_instantiate(), "scène : %s" % file)


func _list_files(path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for f in dir.get_files():
		out.append(path + "/" + f)
	for d in dir.get_directories():
		out.append_array(_list_files(path + "/" + d))
	return out


func _test_unit_data_matches_gdd() -> void:
	# GDD v0.2 §5.1 : effectif, PV, dégâts, portée, déplacement.
	var expected := {
		&"warrior": [4, 50, 10, 1, 1.0],
		&"archer": [2, 30, 20, 3, 2.0],
		&"cavalier": [2, 75, 15, 1, 4.0],
		&"mage": [1, 25, 10, 1, 1.0],
		&"healer": [1, 35, 0, 3, 2.0],
		&"miner": [1, 50, 5, 1, 4.0],
	}
	check(UnitDatabase.load_all().size() == expected.size(), "6 unités chargées")
	for id in expected:
		var u := UnitDatabase.get_unit(id)
		check(u != null, "unité %s présente" % id)
		if u == null:
			continue
		var e: Array = expected[id]
		check([u.squad_size, u.hp, u.damage, u.attack_range, u.move_speed] == e,
				"%s conforme au GDD (%s)" % [id, e])
		check(u.sprite != null, "%s a un sprite" % id)
	var mage := UnitDatabase.get_unit(&"mage")
	check(mage.burn_damage == 2 and mage.burn_turns == 2, "mage : brûlure 2 dégâts x 2 tours")
	var healer := UnitDatabase.get_unit(&"healer")
	check(healer.action == UnitData.ActionType.HEAL and healer.heal_amount == 5, "soigneur : soin de 5")
	check(UnitDatabase.get_unit(&"miner").can_mine, "mineur : peut miner")


func _test_one_individual_per_cell() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5))
	var w2 := spawn(&"warrior", 0, Vector2i(5, 5))
	check(w.alive_count() == 4, "escouade de 4 guerriers")
	var cells := w.cells() + w2.cells()
	var unique := {}
	for c in cells:
		unique[c] = true
	check(unique.size() == 8, "8 guerriers sur 8 cases distinctes")
	_clear_squads()


func _test_squad_totals() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5))
	check(w.total_hp() == 200, "4 guerriers = 200 PV")
	var a := spawn(&"archer", 1, Vector2i(9, 5), [Vector2i(6, 5), Vector2i(6, 6)])
	a.members[1].hp = 1000  # absorbe tous les coups
	var target: Individual = a.members[1]
	var before := target.hp
	for m in w.members:
		CombatSystem.perform_action(m, target)
	check(before - target.hp == 40, "4 guerriers = 40 dégâts")
	_clear_squads()


func _test_individual_damage_and_removal() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var a := spawn(&"archer", 1, Vector2i(6, 5), [Vector2i(6, 5), Vector2i(7, 5)])
	var first: Individual = a.members[0]
	for i in 3:
		CombatSystem.perform_action(w.members[0], first)
	check(a.alive_count() == 1, "archer à 0 PV retiré de l'escouade")
	check(a.total_hp() == 30, "l'autre archer est intact")
	check(map.occupant(Vector2i(6, 5)) == null, "la case de l'archer mort est libérée")
	_clear_squads()


func _test_squad_destruction() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5), [Vector2i(5, 5), Vector2i(5, 6), Vector2i(5, 4), Vector2i(4, 5)])
	var m := spawn(&"mage", 1, Vector2i(6, 5), [Vector2i(6, 5)])
	var destroyed := [false]
	m.destroyed.connect(func(_s): destroyed[0] = true)
	for i in 3:
		CombatSystem.perform_action(w.members[i], m.members[0])
	check(destroyed[0], "escouade détruite quand tous les individus meurent")
	check(not m.is_alive(), "mage mort")
	_clear_squads()


func _test_range_per_individual() -> void:
	var a := spawn(&"archer", 0, Vector2i(5, 5), [Vector2i(5, 5), Vector2i(5, 9)])
	var e := spawn(&"warrior", 1, Vector2i(8, 7), [Vector2i(8, 7), Vector2i(9, 5)])
	check(CombatSystem.in_range(a.members[0], e.members[0]), "archer : cible à 3 cases à portée")
	check(not CombatSystem.in_range(a.members[0], e.members[1]), "archer : cible à 4 cases hors portée")
	check(CombatSystem.in_range(a.members[1], e.members[0]), "la portée se mesure depuis la case de chaque individu")
	_clear_squads()


func _test_area_patterns() -> void:
	var mage := UnitDatabase.get_unit(&"mage")
	check(CombatSystem.affected_cells(mage, Vector2i(0, 0), Vector2i(1, 0)) == [Vector2i(1, 0), Vector2i(2, 0)],
			"mage : 2 cases horizontales")
	check(CombatSystem.affected_cells(mage, Vector2i(0, 0), Vector2i(0, -1)) == [Vector2i(0, -1), Vector2i(0, -2)],
			"mage : 2 cases verticales")
	var cav := UnitDatabase.get_unit(&"cavalier")
	check(CombatSystem.affected_cells(cav, Vector2i(5, 5), Vector2i(6, 5)).size() == 8, "cavalier : les 8 cases autour")


func _test_cavalier_circle_hits_multiple() -> void:
	var c := spawn(&"cavalier", 0, Vector2i(10, 10), [Vector2i(10, 10), Vector2i(3, 3)])
	var e := spawn(&"warrior", 1, Vector2i(11, 10), [Vector2i(11, 10), Vector2i(9, 11), Vector2i(13, 10), Vector2i(11, 11)])
	var ally := spawn(&"warrior", 0, Vector2i(10, 11), [Vector2i(10, 11)])
	CombatSystem.perform_action(c.members[0], e.members[0])
	var hps: Array = e.members.map(func(m): return m.hp)
	check(hps == [35, 35, 50, 35], "cavalier : touche les 3 guerriers adjacents (15), pas celui à 3 cases (%s)" % [hps])
	check(ally.total_hp() == 50, "pas de tir allié")
	_clear_squads()


func _test_mage_line_hits_two_individuals() -> void:
	var m := spawn(&"mage", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var e := spawn(&"warrior", 1, Vector2i(6, 5), [Vector2i(6, 5), Vector2i(7, 5), Vector2i(6, 6)])
	CombatSystem.perform_action(m.members[0], e.members[0])
	var hps: Array = e.members.map(func(x): return x.hp)
	check(hps == [40, 40, 50], "mage : touche les 2 cases alignées, pas la diagonale (%s)" % [hps])
	check(e.members[0].is_burning() and e.members[1].is_burning() and not e.members[2].is_burning(),
			"mage : seuls les individus touchés brûlent")
	_clear_squads()


func _test_pathfinding_avoids_water() -> void:
	var path := map.find_path(Vector2i(3, 3), Vector2i(map.width - 4, map.height - 4))
	check(not path.is_empty(), "chemin trouvé d'un royaume à l'autre")
	var ok := true
	for c in path:
		ok = ok and map.is_walkable(c)
	check(ok, "le chemin n'emprunte que des cases praticables (gués)")


func _test_movement_speed() -> void:
	# Cavalier : 4 cases/tour -> 4 cases en GameConfig.SECONDS_PER_TURN secondes.
	var c := spawn(&"cavalier", 0, Vector2i(2, 2), [Vector2i(2, 2), Vector2i(2, 3)])
	c.order_move_cells([Vector2i(6, 2), Vector2i(6, 3)])
	var t := 0.0
	while c.state == Squad.State.MOVING and t < 10.0:
		c.tick(0.05)
		t += 0.05
	check(c.cells() == [Vector2i(6, 2), Vector2i(6, 3)], "cavaliers arrivés chacun sur leur case")
	check(absf(t - GameConfig.SECONDS_PER_TURN) < 0.11, "cavalier : 4 cases en 1 tour (%.2fs)" % t)
	_clear_squads()


func _test_group_move_keeps_one_per_cell() -> void:
	var a := spawn(&"warrior", 0, Vector2i(4, 8))
	var b := spawn(&"warrior", 0, Vector2i(4, 14))
	a.order_move(Vector2i(10, 10))
	b.order_move(Vector2i(10, 10))
	_run_ticks([a, b], 12.0)
	check(_cells_unique(), "déplacement vers un même point : un individu par case")
	check(a.state == Squad.State.IDLE and b.state == Squad.State.IDLE, "les deux escouades sont arrivées")
	_clear_squads()


func _test_attack_order_chases_and_kills() -> void:
	var w := spawn(&"warrior", 0, Vector2i(2, 10))
	var m := spawn(&"mage", 1, Vector2i(8, 10), [Vector2i(8, 10)])
	w.order_target(m)
	_run_ticks([w], 20.0)
	check(not is_instance_valid(m) or not m.is_alive(), "les guerriers rejoignent et éliminent le mage")
	check(w.total_hp() == 200, "guerriers intacts (le mage n'a pas été simulé)")
	_clear_squads()


func _test_mage_burn() -> void:
	var m := spawn(&"mage", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var w := spawn(&"warrior", 1, Vector2i(10, 5), [Vector2i(6, 5)])
	var ind: Individual = w.members[0]
	CombatSystem.perform_action(m.members[0], ind)
	check(ind.hp == 40, "mage : 10 dégâts immédiats")
	check(ind.is_burning(), "mage : la cible brûle")
	w.state = Squad.State.MOVING  # empêche la riposte automatique pendant le test
	_run_ticks([w], GameConfig.SECONDS_PER_TURN)
	check(ind.hp == 38, "brûlure : 2 dégâts au 1er tour (%d)" % ind.hp)
	_run_ticks([w], GameConfig.SECONDS_PER_TURN)
	check(ind.hp == 36, "brûlure : 2 dégâts au 2e tour (%d)" % ind.hp)
	_run_ticks([w], GameConfig.SECONDS_PER_TURN * 2)
	check(ind.hp == 36 and not ind.is_burning(), "brûlure terminée après 2 tours")
	_clear_squads()


func _test_burn_refresh() -> void:
	var m := spawn(&"mage", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var w := spawn(&"warrior", 1, Vector2i(10, 5), [Vector2i(6, 5)])
	var ind: Individual = w.members[0]
	w.state = Squad.State.MOVING
	CombatSystem.perform_action(m.members[0], ind)
	CombatSystem.perform_action(m.members[0], ind)
	check(ind.burns.size() == 1, "deux brûlures du mage ne se cumulent pas")
	_run_ticks([w], GameConfig.SECONDS_PER_TURN * 3)
	check(ind.hp == 50 - 20 - 4, "brûlure renouvelée : 2 tours seulement (%d)" % ind.hp)
	_clear_squads()


func _test_heal() -> void:
	var h := spawn(&"healer", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var w := spawn(&"warrior", 0, Vector2i(8, 5), [Vector2i(8, 5), Vector2i(9, 5), Vector2i(8, 6)])
	var enemy := spawn(&"warrior", 1, Vector2i(8, 4), [Vector2i(8, 4)])
	w.members[0].hp = 30
	w.members[1].hp = 48
	w.members[2].hp = 20
	enemy.members[0].hp = 40
	CombatSystem.perform_action(h.members[0], w.members[0])
	var hps: Array = w.members.map(func(x): return x.hp)
	check(hps == [35, 50, 20], "soin : +5 PV sur les 2 cases alignées, plafonné aux PV max (%s)" % [hps])
	check(enemy.total_hp() == 40, "soin : les ennemis ne sont pas soignés")
	check(not CombatSystem.can_target(h, enemy), "soigneur : ne cible pas un ennemi")
	check(not w.order_target(h), "guerrier : ne cible pas un allié")
	_clear_squads()


func _test_healer_auto_heals_and_never_attacks() -> void:
	var h := spawn(&"healer", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var w := spawn(&"warrior", 0, Vector2i(7, 5), [Vector2i(7, 5)])
	var enemy := spawn(&"archer", 1, Vector2i(6, 6), [Vector2i(6, 6)])
	enemy.state = Squad.State.MOVING  # passif
	w.state = Squad.State.MOVING
	w.members[0].hp = 20
	_run_ticks([h], GameConfig.SECONDS_PER_TURN * 3)
	check(w.total_hp() > 20, "soigneur inactif : soigne automatiquement un allié blessé")
	check(enemy.total_hp() == 30, "soigneur : n'attaque jamais")
	_clear_squads()


## Deux armées complètes s'affrontent : aucune erreur, un individu par case à l'arrêt.
func _test_full_battle_invariants() -> void:
	var army: Array[StringName] = [&"warrior", &"warrior", &"archer", &"cavalier", &"mage", &"healer", &"miner"]
	var squads: Array = []
	for team in 2:
		for i in army.size():
			var s := spawn(army[i], team, Vector2i(20 if team == 0 else 39, 6 + i * 3))
			squads.append(s)
	for s in squads:
		var enemies := squads.filter(func(o): return o.team != s.team)
		if s.data.action == UnitData.ActionType.ATTACK:
			s.order_target(enemies[squads.find(s) % enemies.size()])
		else:
			s.order_move(Vector2i(28 if s.team == 0 else 31, 16))
	_run_ticks(squads, 40.0)
	var alive := squads.filter(func(s): return is_instance_valid(s) and s.is_alive())
	check(alive.size() < squads.size(), "bataille : des escouades ont été détruites")
	check(_cells_unique(), "bataille : un individu par case à l'arrêt")
	_clear_squads()


## Commandes à un seul bouton (trackpad) : clic = choisir, puis clic = ordre.
func _test_one_button_controls() -> void:
	var sel := SelectionController.new()
	sel.map = map
	root.add_child(sel)
	var w := spawn(&"warrior", 0, Vector2i(5, 5))
	var h := spawn(&"healer", 0, Vector2i(5, 9), [Vector2i(5, 9)])
	var e := spawn(&"archer", 1, Vector2i(9, 5))
	sel._on_click(w.members[0].position, false, false)
	check(sel.selected == [w], "clic sur une escouade alliée : elle est choisie")
	sel._on_click(map.cell_to_world(Vector2i(8, 12)), false, false)
	check(w.state == Squad.State.MOVING, "clic sur le terrain : la sélection s'y déplace")
	check(sel.selected == [w], "la sélection est conservée après l'ordre")
	sel._on_click(e.members[0].position, false, false)
	check(w.state == Squad.State.ACTING and w.target == e, "clic sur un ennemi : attaque")
	sel._on_click(h.members[0].position, true, false)
	check(sel.selected.size() == 2, "Maj + clic : ajoute à la sélection")
	sel._on_click(h.members[0].position, true, false)
	check(sel.selected == [w], "Maj + clic à nouveau : retire de la sélection")
	sel.set_selection([h])
	w.members[0].hp = 10
	sel._on_click(w.members[0].position, false, true)
	check(h.state == Squad.State.ACTING and h.target == w, "Option + clic sur un allié blessé : soin")
	sel.select_all()
	check(sel.selected.size() == 2, "tout choisir : toutes les escouades du joueur")
	sel.stop_selected()
	check(w.state == Squad.State.IDLE, "stop")
	sel.free()
	_clear_squads()


## Régression : une escouade dont la cible est détruite (et libérée) ne plante pas.
func _test_dead_target_does_not_crash() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5))
	var m := spawn(&"mage", 1, Vector2i(6, 5), [Vector2i(7, 5)])
	w.order_target(m)
	m.free()
	_run_ticks([w], 1.0)
	check(w.state == Squad.State.IDLE, "cible détruite : l'escouade s'arrête proprement")
	_clear_squads()
