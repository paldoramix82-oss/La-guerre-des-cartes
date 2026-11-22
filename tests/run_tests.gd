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
	map.auto_generate = false
	root.add_child(map)
	if map.tiles.is_empty():
		map.generate_placeholder_layout()
	_test_all_scripts_compile()
	_test_unit_data_matches_gdd()
	_test_unit_costs_match_document()
	_test_buildings_match_document()
	_test_one_individual_per_cell()
	_test_squad_totals()
	_test_individual_damage_and_removal()
	_test_squad_destruction()
	_test_range_per_individual()
	_test_area_patterns()
	_test_cavalier_circle_hits_multiple()
	_test_mage_line_hits_two_individuals()
	_test_pathfinding_avoids_water()
	_test_path_avoids_occupied_cells()
	_test_movement_speed()
	_test_group_move_keeps_one_per_cell()
	_test_attack_order_chases_and_kills()
	_test_mage_burn()
	_test_burn_refresh()
	_test_heal()
	_test_healer_auto_heals_and_never_attacks()
	_test_full_battle_invariants()
	_test_one_button_controls()
	_test_economy_start()
	_test_placement_rules()
	_test_worker_hut()
	_test_construction_speed()
	_test_harvest_and_depletion()
	_test_storage_cap()
	_test_production_and_upkeep()
	_test_income_per_turn()
	_test_unit_upkeep_values()
	_test_unfed_squad_stops()
	_test_recruitment()
	_test_select_barracks_and_recruit_click()
	_test_combat_effects()
	_test_map_generator()
	_test_fog_of_war()
	_test_deck_composition()
	_test_play_card_cycle()
	_test_malus_occupies_hand()
	_test_neutral_cards()
	_test_field_cards_and_mana()
	_test_food_shortage_stops_workers()
	_test_build_mode_and_work_clicks()
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
	# Statistiques de l'auteur : effectif, PV, dégâts / attaque, portée, déplacement, intervalle (s).
	var expected := {
		&"warrior": [4, 50, 5, 1, 1.0, 2.5],
		&"archer": [2, 30, 10, 3, 2.0, 3.0],
		&"cavalier": [2, 75, 8, 1, 4.0, 4.0],
		&"mage": [1, 25, 6, 2, 1.0, 3.0],
		&"healer": [1, 35, 0, 3, 2.0, 3.0],
		&"miner": [1, 50, 5, 1, 4.0, 3.0],
		&"worker": [1, 30, 0, 1, 2.0, 3.0],
	}
	check(UnitDatabase.load_all().size() == expected.size(), "7 unités chargées")
	for id in expected:
		var u := UnitDatabase.get_unit(id)
		check(u != null, "unité %s présente" % id)
		if u == null:
			continue
		var e: Array = expected[id]
		check([u.squad_size, u.hp, u.damage, u.attack_range, u.move_speed, u.attack_interval] == e,
				"%s conforme aux valeurs de l'auteur (%s)" % [id, e])
		check(u.sprite != null, "%s a un sprite" % id)
	var mage := UnitDatabase.get_unit(&"mage")
	check(mage.burn_damage == 2 and is_equal_approx(mage.burn_seconds, 4.0), "mage : brûlure 2 PV/s pendant 4 s")
	var dps := func(id): var u := UnitDatabase.get_unit(id); return u.squad_size * u.damage / u.attack_interval
	check(is_equal_approx(dps.call(&"warrior"), 8.0) and is_equal_approx(dps.call(&"archer"), 20.0 / 3.0)
			and is_equal_approx(dps.call(&"cavalier"), 4.0), "DPS d'escouade : guerrier 8, archer 6,67, cavalier 4")
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
	check(before - target.hp == 20, "4 guerriers = 20 dégâts collectifs")
	_clear_squads()


func _test_individual_damage_and_removal() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var a := spawn(&"archer", 1, Vector2i(6, 5), [Vector2i(6, 5), Vector2i(7, 5)])
	var first: Individual = a.members[0]
	for i in 6:
		CombatSystem.perform_action(w.members[0], first)
	check(a.alive_count() == 1, "archer à 0 PV retiré de l'escouade (6 coups de 5)")
	check(a.total_hp() == 30, "l'autre archer est intact")
	check(map.occupant(Vector2i(6, 5)) == null, "la case de l'archer mort est libérée")
	_clear_squads()


func _test_squad_destruction() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5), [Vector2i(5, 5), Vector2i(5, 6), Vector2i(5, 4), Vector2i(4, 5)])
	var m := spawn(&"mage", 1, Vector2i(6, 5), [Vector2i(6, 5)])
	var destroyed := [false]
	m.destroyed.connect(func(_s): destroyed[0] = true)
	for i in 5:
		CombatSystem.perform_action(w.members[i % 4], m.members[0])
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
	check(hps == [42, 42, 50, 42], "cavalier : 8 dégâts à chacun des 3 guerriers adjacents, pas à celui à 3 cases (%s)" % [hps])
	check(ally.total_hp() == 50, "pas de tir allié")
	_clear_squads()


func _test_mage_line_hits_two_individuals() -> void:
	var m := spawn(&"mage", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var e := spawn(&"warrior", 1, Vector2i(6, 5), [Vector2i(6, 5), Vector2i(7, 5), Vector2i(6, 6)])
	CombatSystem.perform_action(m.members[0], e.members[0])
	var hps: Array = e.members.map(func(x): return x.hp)
	check(hps == [44, 44, 50], "mage : 6 dégâts sur les 2 cases alignées, pas la diagonale (%s)" % [hps])
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
	# Cavalier : 4 cases par seconde.
	var c := spawn(&"cavalier", 0, Vector2i(2, 2), [Vector2i(2, 2), Vector2i(2, 3)])
	c.order_move_cells([Vector2i(6, 2), Vector2i(6, 3)])
	var t := 0.0
	while c.state == Squad.State.MOVING and t < 10.0:
		c.tick(0.05)
		t += 0.05
	check(c.cells() == [Vector2i(6, 2), Vector2i(6, 3)], "cavaliers arrivés chacun sur leur case")
	check(absf(t - 1.0) < 0.11, "cavalier : 4 cases en 1 seconde (%.2fs)" % t)
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
	check(ind.hp == 44, "mage : 6 dégâts immédiats")
	check(ind.is_burning(), "mage : la cible brûle")
	w.state = Squad.State.MOVING  # empêche la riposte automatique pendant le test
	_run_ticks([w], 1.0)
	check(ind.hp == 42, "brûlure : 2 PV après 1 s (%d)" % ind.hp)
	_run_ticks([w], 3.0)
	check(ind.hp == 36, "brûlure : 8 PV en 4 s, soit 14 dégâts au total (%d)" % ind.hp)
	_run_ticks([w], 2.0)
	check(ind.hp == 36 and not ind.is_burning(), "brûlure terminée après 4 s")
	_clear_squads()


func _test_burn_refresh() -> void:
	var m := spawn(&"mage", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var m2 := spawn(&"mage", 0, Vector2i(5, 7), [Vector2i(5, 7)])
	var w := spawn(&"warrior", 1, Vector2i(10, 5), [Vector2i(6, 5)])
	var ind: Individual = w.members[0]
	w.state = Squad.State.MOVING
	CombatSystem.perform_action(m.members[0], ind)
	_run_ticks([w], 2.0)
	CombatSystem.perform_action(m.members[0], ind)
	check(ind.burns.size() == 1, "le même mage : la brûlure ne se cumule pas")
	_run_ticks([w], 6.0)
	# 6 + 2x2 (2 s) + 6 + 4x2 (durée relancée à 4 s) = 24
	check(ind.hp == 50 - 24, "le même mage : la durée repart à 4 s (%d)" % ind.hp)
	ind.hp = 50
	CombatSystem.perform_action(m.members[0], ind)
	CombatSystem.perform_action(m2.members[0], ind)
	check(ind.burns.size() == 2, "deux mages : deux brûlures")
	_run_ticks([w], 1.0)
	check(ind.hp == 50 - 12 - 4, "deux mages : les brûlures s'additionnent (4 PV/s) (%d)" % ind.hp)
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


## Coûts de création des unités (document « Le RTS »).
func _test_unit_costs_match_document() -> void:
	var expected := {
		&"warrior": {&"food": 4, &"gold": 50},
		&"archer": {&"food": 2, &"gold": 30},
		&"cavalier": {&"food": 5, &"gold": 100},
		&"mage": {&"food": 1, &"gold": 40},
		&"healer": {&"food": 1, &"gold": 30},
		&"miner": {&"food": 2, &"gold": 20},
	}
	for id in expected:
		check(UnitDatabase.get_unit(id).cost == expected[id], "coût de %s conforme au document" % id)
	check(UnitDatabase.get_unit(&"worker").is_worker, "ouvrier : récolte et construit")


## Bâtiments, défenses et siège (document « Le RTS ») : [PV, coût, tours, stockage, production, conso].
func _test_buildings_match_document() -> void:
	var G := ResourceTypes.GOLD
	var B := ResourceTypes.WOOD
	var M := ResourceTypes.METAL
	var O := ResourceTypes.ORGANIC
	var F := ResourceTypes.FOOD
	var expected := {
		&"bank": [250, {G: 200, B: 10, M: 5}, 4, {G: 2000}, {}, {F: 10}],
		&"mill": [100, {G: 50, B: 5}, 3, {F: 100}, {}, {F: 4}],
		&"warehouse": [125, {G: 100, B: 7, M: 2}, 2, {B: 50, M: 25, O: 30}, {}, {F: 6}],
		&"crop": [50, {G: 20, B: 4, O: 2}, 1, {}, {F: 10}, {}],
		&"farm": [125, {G: 50, B: 8, O: 6}, 2, {}, {F: 25, O: 2}, {F: 2}],
		&"mine": [0, {G: 75, B: 5, M: 3}, 2, {}, {}, {F: 3}],
		&"archer_tower": [100, {B: 4, M: 2, G: 60}, 3, {}, {}, {F: 2}],
		&"cannon": [150, {B: 2, M: 5, G: 100}, 4, {}, {}, {}],
		&"guard_hut": [50, {B: 2, G: 20}, 1, {}, {}, {F: 2}],
		&"barricade": [50, {B: 1, M: 1, G: 10}, 0, {}, {}, {}],
		&"mortar": [125, {B: 6, M: 4, G: 125}, 4, {}, {}, {}],
		&"ladder": [0, {B: 1, G: 5}, 0, {}, {}, {}],
		&"siege_cannon": [75, {B: 2, M: 1, G: 120}, 2, {}, {}, {}],
		&"worker_hut": [0, {B: 2}, 0, {}, {}, {F: 3}],
		&"barracks": [0, {G: 100}, 4, {}, {}, {}],
	}
	check(BuildingDatabase.load_all().size() == expected.size(), "%d bâtiments chargés" % expected.size())
	for id in expected:
		var b := BuildingDatabase.get_building(id)
		check(b != null, "bâtiment %s présent" % id)
		if b == null:
			continue
		var e: Array = expected[id]
		check([b.hp, b.cost, b.build_turns, b.storage, b.production, b.upkeep] == e,
				"%s conforme au document" % id)
	var dmg := {&"archer_tower": [20, 7, 0], &"cannon": [40, 4, 0], &"guard_hut": [10, 3, 0], &"mortar": [30, 6, 2], &"siege_cannon": [75, 1, 0]}
	for id in dmg:
		var b := BuildingDatabase.get_building(id)
		check([b.damage, b.attack_range, b.min_range] == dmg[id], "%s : dégâts / portée conformes" % id)
	check(BuildingDatabase.get_building(&"guard_hut").occupants == 2, "cabane garde : 2 gardes")
	check(BuildingDatabase.get_building(&"worker_hut").workers == 2, "cabane ouvrier : 2 ouvriers")
	check(BuildingDatabase.get_building(&"barracks").recruit_per_turn[&"warrior"] == 4, "caserne : 4 guerriers / tour")


# --- Prototype 2 : économie ---------------------------------------------------------

func _new_economy() -> EconomySystem:
	var e := EconomySystem.new()
	e.map = map
	root.add_child(e)
	return e


func _clear_economy(e: EconomySystem) -> void:
	for o in get_nodes_in_group(MapObject.GROUP):
		o.free()
	e.free()
	_clear_squads()


func _spawn_worker(team: int, cell: Vector2i, home: Building = null) -> Squad:
	var w := spawn(&"worker", team, cell, [cell])
	w.home = home
	return w


func _deposit(id: StringName, cell: Vector2i, e: EconomySystem) -> Deposit:
	var d := Deposit.new()
	root.add_child(d)
	return d.setup(DepositDatabase.get_deposit(id), map, cell, e)


## Avance escouades + économie ensemble.
func _run_world(e: EconomySystem, squads: Array, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		for s in squads:
			if is_instance_valid(s):
				s.tick(0.05)
		e.tick(0.05)
		_flush_deleted()
		for o in get_nodes_in_group(MapObject.GROUP):
			if o.is_queued_for_deletion():
				o.free()
		t += 0.05


func _test_economy_start() -> void:
	var e := _new_economy()
	var econ := e.economy(0)
	check([econ.get_amount(&"gold"), econ.get_amount(&"food"), econ.get_amount(&"organic"),
			econ.get_amount(&"wood"), econ.get_amount(&"metal")] == [1000, 50, 10, 20, 10],
			"ressources de départ : 1000 Gd, 50 Nourri, 10 O, 20 Bs, 10 Ml")
	check([econ.capacity(&"gold"), econ.capacity(&"wood"), econ.capacity(&"metal"),
			econ.capacity(&"organic"), econ.capacity(&"food")] == [2000, 50, 25, 25, 100],
			"stockage de base : 2000 Gd, 50 Bs, 25 Ml, 25 O, 100 Nourri")
	check(e.economy(1).get_amount(&"gold") == 1000, "le joueur 2 a les mêmes ressources")
	_clear_economy(e)


func _test_placement_rules() -> void:
	var e := _new_economy()
	var crop := BuildingDatabase.get_building(&"crop")
	check(e.placement_error(crop, 0, Vector2i(30, 5)) != "", "pas de construction hors de son royaume")
	check(e.placement_error(crop, 0, Vector2i(2, 2)) == "", "construction possible dans son royaume")
	var b := e.place_building(crop, 0, Vector2i(2, 2))
	check(b != null and e.economy(0).get_amount(&"gold") == 980 and e.economy(0).get_amount(&"wood") == 16,
			"le coût est payé (20 Gd, 4 Bs, 2 O)")
	check(e.placement_error(crop, 0, Vector2i(2, 2)) != "", "pas deux bâtiments sur la même case")
	check(not map.is_walkable(Vector2i(2, 2)), "un bâtiment bloque le passage")
	var poor := e.economy(0)
	poor.amounts[&"gold"] = 10
	check(e.placement_error(crop, 0, Vector2i(4, 4)) == "Ressources insuffisantes.", "ressources insuffisantes")
	check(e.placement_error(BuildingDatabase.get_building(&"archer_tower"), 0, Vector2i(4, 4)) != "",
			"défenses pas encore constructibles")
	_clear_economy(e)


func _test_worker_hut() -> void:
	var e := _new_economy()
	var asked := []
	e.workers_requested.connect(func(b, n): asked.append(n))
	var hut := e.place_building(BuildingDatabase.get_building(&"worker_hut"), 0, Vector2i(3, 3))
	check(hut.is_complete, "cabane ouvrier construite d'un coup")
	check(asked == [2], "cabane ouvrier : 2 ouvriers")
	check(e.economy(0).get_amount(&"wood") == 18, "cabane ouvrier : coûte 2 Bs")
	e.process_turn()
	check(e.economy(0).get_amount(&"food") == 47, "cabane ouvrier : consomme 3 Nourri par tour")
	_clear_economy(e)


func _test_construction_speed() -> void:
	var e := _new_economy()
	var farm_data := BuildingDatabase.get_building(&"farm")  # 2 tours
	e.economy(0).amounts[&"organic"] = 25
	var f1 := e.place_building(farm_data, 0, Vector2i(5, 5))
	var w1 := _spawn_worker(0, Vector2i(5, 6))
	w1.order_work(f1)
	_run_world(e, [w1], GameConfig.SECONDS_PER_TURN * 2 - 0.2)
	check(not f1.is_complete, "1 ouvrier : la ferme n'est pas finie avant 2 tours")
	_run_world(e, [w1], 0.4)
	check(f1.is_complete, "1 ouvrier : ferme construite en 2 tours")
	var f2 := e.place_building(farm_data, 0, Vector2i(9, 5))
	var a := _spawn_worker(0, Vector2i(9, 6))
	var b := _spawn_worker(0, Vector2i(9, 4))
	a.order_work(f2)
	b.order_work(f2)
	_run_world(e, [a, b], GameConfig.SECONDS_PER_TURN + 0.2)
	check(f2.is_complete, "2 ouvriers : 2 fois plus rapide")
	check(a.state == Squad.State.IDLE, "chantier terminé : l'ouvrier s'arrête")
	_clear_economy(e)


func _test_harvest_and_depletion() -> void:
	var e := _new_economy()
	var d := _deposit(&"metal_vein", Vector2i(6, 10), e)
	d.remaining = 5
	var d2 := _deposit(&"metal_vein", Vector2i(9, 10), e)
	var w := _spawn_worker(0, Vector2i(3, 10))
	check(w.order_work(d), "ouvrier : ordre de récolte")
	var start := e.economy(0).get_amount(&"metal")
	_run_world(e, [w], 2.0 + GameConfig.SECONDS_PER_TURN + 0.1)  # trajet + 1 tour
	check(e.economy(0).get_amount(&"metal") >= start + 2, "récolte sur place : +2 métal par tour")
	_run_world(e, [w], GameConfig.SECONDS_PER_TURN * 3)
	check(not is_instance_valid(d), "gisement épuisé : il disparaît")
	check(w.state == Squad.State.WORKING and w.work_target == d2, "l'ouvrier passe au filon voisin")
	check(not spawn(&"warrior", 0, Vector2i(3, 14)).order_work(d2), "seuls les ouvriers récoltent")
	_clear_economy(e)


func _test_storage_cap() -> void:
	var e := _new_economy()
	var econ := e.economy(0)
	econ.amounts[&"wood"] = 49
	check(econ.add(&"wood", 5) == 1 and econ.get_amount(&"wood") == 50, "stockage plein : l'excédent n'est pas stocké")
	econ.amounts[&"gold"] = 1000
	var wh := e.place_building(BuildingDatabase.get_building(&"warehouse"), 0, Vector2i(4, 8))
	var w := _spawn_worker(0, Vector2i(4, 9))
	w.order_work(wh)
	_run_world(e, [w], GameConfig.SECONDS_PER_TURN * 2 + 0.2)
	check(wh.is_complete and econ.capacity(&"wood") == 100 and econ.capacity(&"metal") == 50 and econ.capacity(&"organic") == 55,
			"entrepôt terminé : +50 Bs, +25 Ml, +30 O de stockage")
	_clear_economy(e)


func _test_production_and_upkeep() -> void:
	var e := _new_economy()
	var econ := e.economy(0)
	e.place_building(BuildingDatabase.get_building(&"crop"), 0, Vector2i(3, 5))._complete()
	econ.amounts[&"food"] = 50
	e.process_turn()
	check(econ.get_amount(&"food") == 60, "culture : +10 Nourri par tour")
	econ.amounts[&"organic"] = 25
	var farm := e.place_building(BuildingDatabase.get_building(&"farm"), 0, Vector2i(3, 7))
	e.process_turn()
	check(econ.get_amount(&"food") == 70, "chantier : ni production ni consommation")
	farm._complete()
	econ.amounts[&"food"] = 20
	e.process_turn()
	check(econ.get_amount(&"food") == 20 + 10 + 25 - 2, "ferme : +25, consomme 2 (%d)" % econ.get_amount(&"food"))
	_clear_economy(e)


func _test_food_shortage_stops_workers() -> void:
	var e := _new_economy()
	var econ := e.economy(0)
	var hut := e.place_building(BuildingDatabase.get_building(&"worker_hut"), 0, Vector2i(3, 12))
	var d := _deposit(&"forest", Vector2i(5, 12), e)
	var w := _spawn_worker(0, Vector2i(4, 12), hut)
	w.order_work(d)
	econ.amounts[&"food"] = 2  # ne peut pas payer les 3 Nourri
	_run_world(e, [w], GameConfig.SECONDS_PER_TURN + 0.1)  # le tour constate le manque
	check(not hut.fed, "plus de nourriture : la cabane n'est pas nourrie")
	econ.amounts[&"wood"] = 0
	_run_world(e, [w], GameConfig.SECONDS_PER_TURN * 3)
	check(econ.get_amount(&"wood") == 0, "ouvriers non nourris : ils ne récoltent plus")
	econ.amounts[&"food"] = 50
	_run_world(e, [w], GameConfig.SECONDS_PER_TURN * 2 + 0.1)
	check(hut.fed and econ.get_amount(&"wood") > 0, "nourriture revenue : la récolte reprend")
	_clear_economy(e)


func _test_build_mode_and_work_clicks() -> void:
	var e := _new_economy()
	var sel := SelectionController.new()
	sel.map = map
	sel.economy_system = e
	root.add_child(sel)
	var w := _spawn_worker(0, Vector2i(6, 15))
	var d := _deposit(&"berries", Vector2i(8, 15), e)
	sel._on_click(w.members[0].position, false, false)
	sel._on_click(d.position, false, false)
	check(w.state == Squad.State.WORKING and w.work_target == d, "ouvrier choisi + clic sur un gisement : récolte")
	sel.start_build(BuildingDatabase.get_building(&"mill"))
	var b := sel.try_place_building(Vector2i(6, 18))
	check(b != null and w.work_target == b, "mode construction : le chantier est posé et l'ouvrier choisi y va")
	check(sel.build_data == null, "mode construction quitté après la pose")
	sel.start_build(BuildingDatabase.get_building(&"mill"))
	check(sel.try_place_building(Vector2i(40, 18)) == null, "pose refusée hors du royaume")
	sel.free()
	_clear_economy(e)


## Revenu net du tour (affiché « (+x) » dans la barre de ressources).
func _test_income_per_turn() -> void:
	var e := _new_economy()
	var econ := e.economy(0)
	e.place_building(BuildingDatabase.get_building(&"crop"), 0, Vector2i(3, 5))._complete()
	e.place_building(BuildingDatabase.get_building(&"worker_hut"), 0, Vector2i(3, 7))
	econ.amounts[&"food"] = 20
	e.process_turn()
	check(econ.last_income.get(&"food", 0) == 10 - 3, "revenu du tour : +10 culture - 3 cabane = +7")
	econ.pay({&"gold": 100})
	e.process_turn()
	check(not econ.last_income.has(&"gold"), "les dépenses de construction ne comptent pas dans le revenu")
	_clear_economy(e)


# --- Nourriture des unités et recrutement (Prototype 3) -----------------------------

func _test_unit_upkeep_values() -> void:
	var expected := {&"warrior": 2, &"archer": 1, &"healer": 1, &"mage": 1, &"cavalier": 3, &"miner": 2}
	for id in expected:
		check(UnitDatabase.get_unit(id).upkeep == {&"food": expected[id]}, "%s : %d Nourri / tour par individu" % [id, expected[id]])
	check(UnitDatabase.get_unit(&"worker").upkeep.is_empty(), "ouvrier : nourri par sa cabane, pas de consommation propre")
	check(UnitDatabase.get_unit(&"warrior").upkeep_for(4) == {&"food": 8}, "escouade de 4 guerriers : 8 Nourri / tour")
	var farm := BuildingDatabase.get_building(&"farm")
	check(farm.production.get(&"organic", 0) == 2, "ferme : +2 Organique / tour")


func _test_unfed_squad_stops() -> void:
	var e := _new_economy()
	var econ := e.economy(0)
	var w := spawn(&"warrior", 0, Vector2i(3, 20))
	econ.amounts[&"food"] = 20
	e.process_turn()
	check(econ.get_amount(&"food") == 12 and w.is_fed(), "4 guerriers : -8 Nourri par tour")
	econ.amounts[&"food"] = 5
	e.process_turn()
	check(not w.is_fed() and econ.get_amount(&"food") == 5, "nourriture insuffisante : l'escouade n'est pas nourrie")
	var before := w.cells()
	w.order_move(Vector2i(9, 20))
	_run_world(e, [w], 0.5)
	check(w.cells() == before, "escouade non nourrie : elle ne bouge plus")
	econ.amounts[&"food"] = 50
	_run_world(e, [w], GameConfig.SECONDS_PER_TURN + 0.1)
	check(w.is_fed(), "nourriture revenue : l'escouade repart")
	_clear_economy(e)


func _barracks(e: EconomySystem, cell: Vector2i) -> Building:
	var b := e.place_building(BuildingDatabase.get_building(&"barracks"), 0, cell)
	b._complete()
	return b


func _test_recruitment() -> void:
	var e := _new_economy()
	var econ := e.economy(0)
	var warrior := UnitDatabase.get_unit(&"warrior")
	check(e.recruit_error(warrior, 0) == "Construisez d'abord une Caserne.", "recrutement impossible sans Caserne")
	var b := _barracks(e, Vector2i(4, 25))
	var got := []
	e.squad_recruited.connect(func(bb, u): got.append(u.id))
	econ.amounts[&"food"] = 100
	var gold_before := econ.get_amount(&"gold")
	check(e.recruit(warrior, 0) == b, "guerriers ajoutés à la file de la Caserne")
	check(econ.get_amount(&"gold") == gold_before - 50 and econ.get_amount(&"food") == 96, "coût payé : 50 Gd, 4 Nourri")
	e.recruit(UnitDatabase.get_unit(&"archer"), 0)
	check(b.queue.size() == 2, "file : 2 escouades")
	check(is_equal_approx(b.recruit_time(warrior), GameConfig.SECONDS_PER_TURN), "4 guerriers à 4 / tour : 1 tour")
	check(is_equal_approx(b.recruit_time(UnitDatabase.get_unit(&"miner")), GameConfig.SECONDS_PER_TURN * 0.5),
			"1 mineur à 2 / tour : un demi-tour")
	e.tick(GameConfig.SECONDS_PER_TURN * 0.6)
	check(got.is_empty(), "une escouade à la fois : rien avant la fin du premier recrutement")
	e.tick(GameConfig.SECONDS_PER_TURN * 0.45)
	check(got == [&"warrior"], "guerriers recrutés après 1 tour")
	e.tick(GameConfig.SECONDS_PER_TURN * 1.05)
	check(got == [&"warrior", &"archer"], "puis les archers")
	econ.amounts[&"gold"] = 10
	check(e.recruit_error(warrior, 0) == "Ressources insuffisantes.", "recrutement : ressources insuffisantes")
	_clear_economy(e)


func _test_select_barracks_and_recruit_click() -> void:
	var e := _new_economy()
	var sel := SelectionController.new()
	sel.map = map
	sel.economy_system = e
	root.add_child(sel)
	var b := _barracks(e, Vector2i(6, 26))
	var w := spawn(&"warrior", 0, Vector2i(3, 30))
	sel.set_selection([w])
	sel._on_click(b.position, false, false)
	check(sel.selected_building == b and sel.selected.is_empty(), "clic sur sa Caserne : elle est choisie")
	sel._on_click(w.members[0].position, false, false)
	check(sel.selected_building == null and sel.selected == [w], "choisir une escouade libère le bâtiment")
	var site := e.place_building(BuildingDatabase.get_building(&"mill"), 0, Vector2i(9, 26))
	var worker := _spawn_worker(0, Vector2i(9, 28))
	sel.set_selection([worker])
	sel._on_click(site.position, false, false)
	check(worker.work_target == site, "ouvriers + clic sur un chantier : construire (pas de sélection)")
	sel.free()
	_clear_economy(e)


## Effets visuels : projectiles et chiffres apparaissent sur le calque d'effets.
func _test_combat_effects() -> void:
	var fx := Effects.new()
	root.add_child(fx)
	var a := spawn(&"archer", 0, Vector2i(5, 5), [Vector2i(5, 5)])
	var w := spawn(&"warrior", 1, Vector2i(8, 5), [Vector2i(8, 5)])
	a.order_target(w)
	_run_ticks([a], 0.1)
	check(fx.get_children().any(func(c): return c is Sprite2D), "archer : une flèche part vers la cible")
	check(fx.get_child_count() >= 2, "un chiffre de dégâts s'affiche (%d effets)" % fx.get_child_count())
	check(UnitDatabase.get_unit(&"archer").projectile != null and UnitDatabase.get_unit(&"mage").projectile != null
			and UnitDatabase.get_unit(&"healer").projectile != null, "archer, mage, soigneur : projectiles définis")
	fx.free()
	_clear_squads()


# --- Grande carte et brouillard de guerre -------------------------------------------

func _test_map_generator() -> void:
	var m := GameMap.new()
	m.auto_generate = false
	root.add_child(m)
	var t0 := Time.get_ticks_msec()
	MapGenerator.generate(m, GameConfig.MAP_SEED)
	var ms := Time.get_ticks_msec() - t0
	print("  génération de la carte : %d ms" % ms)
	check(m.width == GameConfig.MAP_WIDTH and m.height == GameConfig.MAP_HEIGHT, "carte immense : %d x %d" % [m.width, m.height])
	check(ms < 8000, "génération en moins de 8 s (%d ms)" % ms)
	var sym := true
	var counts := {}
	for y in m.height:
		for x in m.width:
			var t := m.get_terrain(Vector2i(x, y))
			counts[t] = counts.get(t, 0) + 1
			if t != m.get_terrain(Vector2i(m.width - 1 - x, m.height - 1 - y)):
				sym = false
	check(sym, "carte symétrique : les deux joueurs ont la même carte")
	var total := float(m.width * m.height)
	var forest: float = counts.get(GameMap.Terrain.FOREST, 0) / total
	var water: float = (counts.get(GameMap.Terrain.WATER, 0) + counts.get(GameMap.Terrain.FORD, 0)) / total
	print("  forêt %d %%, eau %d %%" % [forest * 100, water * 100])
	check(forest > 0.25, "forêt géante (%d %% de la carte)" % (forest * 100))
	check(water > 0.04, "lacs et rivières (%d %% de la carte)" % (water * 100))
	var bases: Array = m.features[&"bases"]
	check(m.kingdom_of(bases[0]) == 0 and m.kingdom_of(bases[1]) == 1, "chaque départ est dans son royaume")
	check(not m.find_path(bases[0], bases[1]).is_empty(), "les deux départs sont reliés")
	var all_ok := true
	var targets: Array = m.features[&"mines"] + m.features[&"camps"] + m.features[&"lairs"].values()
	for e in m.features[&"deposits"]:
		targets.append(e[1])
	for c in targets:
		var near := m.nearest_walkable(c)
		if m.find_path(bases[0], near).is_empty() and near != bases[0]:
			all_ok = false
	check(all_ok, "mines, camps, repaires et gisements accessibles depuis le départ (%d éléments)" % targets.size())
	check(m.features[&"mines"].has(Vector2i(m.width / 2, m.height / 2)), "une mine au centre de la carte")
	check(m.features[&"camps"].size() >= 12, "zones de monstres : %d camps" % m.features[&"camps"].size())
	check(m.features[&"deposits"].size() >= 60, "gisements : %d" % m.features[&"deposits"].size())
	m.free()


func _test_fog_of_war() -> void:
	var fog := FogOfWar.new()
	root.add_child(fog)
	fog.setup(map, 0)
	var base: Vector2i = map.base_of(0)
	check(fog.is_cell_visible(base), "brouillard : le point de départ est visible")
	check(not fog.is_explored(Vector2i(40, 30)), "brouillard : le reste de la carte est inexploré")
	var cav := spawn(&"cavalier", 0, Vector2i(30, 10), [Vector2i(30, 10)])
	var enemy := spawn(&"warrior", 1, Vector2i(36, 10), [Vector2i(36, 10)])
	var far_enemy := spawn(&"warrior", 1, Vector2i(37, 10), [Vector2i(37, 10)])
	fog.update_now()
	check(fog.is_cell_visible(Vector2i(36, 10)), "cavalier : vision 4 + 2 = 6 cases")
	check(not fog.is_cell_visible(Vector2i(37, 10)), "au-delà de 6 cases : hors de vue")
	check(enemy.members[0].visible and not far_enemy.members[0].visible, "ennemi visible en vue, caché hors de vue")
	cav.members[0].place(Vector2i(10, 30))
	fog.update_now()
	check(fog.is_explored(Vector2i(36, 10)) and not fog.is_cell_visible(Vector2i(36, 10)),
			"zone quittée : explorée mais plus en vue")
	check(not enemy.members[0].visible, "ennemi dans une zone explorée hors de vue : caché")
	var w := spawn(&"warrior", 0, Vector2i(20, 20), [Vector2i(20, 20)])
	fog.update_now()
	check(fog.is_cell_visible(Vector2i(23, 20)) and not fog.is_cell_visible(Vector2i(24, 20)), "guerrier : vision 1 + 2 = 3")
	fog.set_team(1)
	check(enemy.members[0].visible and not w.members[0].visible, "changement d'équipe : le brouillard suit le joueur contrôlé")
	fog.free()
	_clear_squads()


# --- Cartes et mana (Prototype 5) -------------------------------------------------------

func _cards(e: EconomySystem = null, seed: int = 1) -> CardSystem:
	var cs := CardSystem.new()
	root.add_child(cs)
	cs.setup(e, seed)
	return cs


## Main contrôlée pour les tests : `ids` en main, `deck_ids` dans le deck (dessus d'abord).
func _set_hand(p: PlayerCards, ids: Array, deck_ids: Array) -> void:
	p.hand.clear()
	p.deck.clear()
	for id in ids:
		p.hand.append(CardDatabase.get_card(id))
	for id in deck_ids:
		p.deck.append(CardDatabase.get_card(id))


func _test_deck_composition() -> void:
	var cs := _cards()
	var p := cs.player(0)
	var all := p.deck + p.hand
	check(all.size() == 20, "deck de 20 cartes (%d)" % all.size())
	var count := func(cat): return all.filter(func(c): return c.category == cat).size()
	check(count.call(CardData.Category.BONUS) == 10 and count.call(CardData.Category.MALUS) == 5
			and count.call(CardData.Category.NEUTRAL) == 5, "10 bonus, 5 malus, 5 neutres")
	check(p.hand.size() == 3 and p.hand_limit == 3, "main initiale de 3 cartes, limite 3")
	var n0 := (cs.player(0).deck + cs.player(0).hand).filter(func(c): return c.category == CardData.Category.NEUTRAL).map(func(c): return c.id)
	var n1 := (cs.player(1).deck + cs.player(1).hand).filter(func(c): return c.category == CardData.Category.NEUTRAL).map(func(c): return c.id)
	n0.sort()
	n1.sort()
	check(n0 == n1, "les deux joueurs ont les mêmes cartes neutres")
	cs.free()


func _test_play_card_cycle() -> void:
	var e := _new_economy()
	var cs := _cards(e)
	var p := cs.player(0)
	_set_hand(p, [&"royal_treasure", &"mana_surge", &"malus_placeholder"], [&"new_draw", &"destruction"])
	p.mana = 2.0
	check(not p.can_play(0) and p.play_error(0).begins_with("Mana insuffisant"), "mana insuffisant : carte injouable")
	p.mana = 5.0
	var gold := e.economy(0).get_amount(&"gold")
	check(p.play(0), "Trésor royal joué")
	check(e.economy(0).get_amount(&"gold") == gold + 200, "effet : +200 Gd immédiatement")
	check(is_equal_approx(p.mana, 2.0), "mana payé (3)")
	check(p.deck.back().id == &"royal_treasure", "la carte retourne sous le deck")
	check(p.hand.size() == 3 and p.hand.back().id == &"new_draw", "la main est complétée par la pioche")
	# Afflux de mana : +50 % de régénération pendant 30 tours.
	var regen := p.mana_regen()
	p.play(0)
	check(is_equal_approx(p.mana_regen(), regen * 1.5), "Afflux de mana : régénération +50 %")
	for i in 30:
		p.on_turn()
	check(is_equal_approx(p.mana_regen(), regen), "bonus de mana terminé après 30 tours")
	cs.free()
	_clear_economy(e)


func _test_malus_occupies_hand() -> void:
	var cs := _cards()
	var p := cs.player(0)
	_set_hand(p, [&"royal_treasure", &"malus_placeholder", &"malus_placeholder"], [&"mana_surge"])
	check(p.usable_count() == 1, "1 normale + 2 malus : 1 carte exploitable (GDD §7.2)")
	check(p.can_play(1), "un malus peut être activé")
	p.play(1)
	check(p.deck.back().id == &"malus_placeholder" and p.hand.size() == 3, "malus activé : sous le deck, puis pioche")
	cs.free()


func _test_neutral_cards() -> void:
	var cs := _cards()
	var p := cs.player(0)
	p.mana = 10.0
	# Extension de main : limite +1, puis la main se complète.
	_set_hand(p, [&"hand_extension", &"royal_treasure", &"mana_surge"], [&"new_draw", &"destruction", &"royal_treasure"])
	p.play(0)
	check(p.hand_limit == 4 and p.hand.size() == 4, "Extension de main : limite 4, main complétée")
	check(not p.deck.any(func(c): return c.id == &"hand_extension"), "Extension de main : usage unique")
	# Nouvelle pioche : une carte de plus, au-delà de la limite.
	p.hand_limit = 3
	_set_hand(p, [&"new_draw", &"royal_treasure", &"mana_surge"], [&"destruction", &"royal_treasure"])
	p.play(0)
	check(p.hand.size() == 3, "Nouvelle pioche : la carte jouée est remplacée et une carte de plus est piochée (%d)" % p.hand.size())
	# Bannissement : choisir un malus, il disparaît définitivement.
	_set_hand(p, [&"banishment", &"royal_treasure", &"malus_placeholder"], [&"mana_surge", &"new_draw"])
	check(p.play(0) and p.pending != null, "Bannissement : attend une carte cible")
	check(not p.choose_target(0), "Bannissement : une carte non malus est refusée")
	check(p.choose_target(1), "Bannissement : malus choisi")
	check(p.banished.size() == 1 and not (p.deck + p.hand).any(func(c): return c.id == &"malus_placeholder"),
			"le malus est retiré définitivement du deck")
	# Destruction : sans cible possible, injouable.
	_set_hand(p, [&"destruction"], [])
	check(not p.can_play(0), "Destruction : injouable sans autre carte en main")
	# Annulation : mana rendu, carte en main.
	_set_hand(p, [&"destruction", &"royal_treasure"], [])
	var mana := p.mana
	p.play(0)
	p.cancel_pending()
	check(p.hand.size() == 2 and is_equal_approx(p.mana, mana), "annulation : carte et mana rendus")
	cs.free()


func _test_field_cards_and_mana() -> void:
	var cs := _cards()
	var p := cs.player(0)
	p.mana = 9.0
	_set_hand(p, [&"royal_treasure", &"mana_surge", &"new_draw"], [&"destruction"])
	var blessing := p.add_field_card(CardDatabase.get_card(&"royal_treasure"))
	check(p.hand.size() == 4 and p.field_cards.size() == 1, "carte du terrain : ajoutée directement à la main")
	p.play(p.hand.find(blessing))
	check(p.field_cards.is_empty() and not p.deck.any(func(c): return c.id == &"royal_treasure"),
			"carte du terrain : jamais ajoutée au deck après usage")
	p.mana = 0.0
	p.regen_boosts.clear()
	for i in 4:
		p.on_turn()
	check(is_equal_approx(p.mana, GameConfig.MANA_REGEN_PER_TURN * 4), "le mana se régénère seul à chaque tour")
	p.mana = GameConfig.MANA_MAX
	p.on_turn()
	check(is_equal_approx(p.mana, GameConfig.MANA_MAX), "le mana est plafonné")
	check(is_equal_approx(cs.player(1).mana_regen(), cs.player(0).mana_regen()), "même régénération pour les deux joueurs")
	cs.free()


## Un individu contourne les cases occupées (décision de l'auteur).
func _test_path_avoids_occupied_cells() -> void:
	var wall := spawn(&"warrior", 1, Vector2i(6, 9), [Vector2i(6, 8), Vector2i(6, 9), Vector2i(6, 10)])
	var path := map.find_path(Vector2i(4, 9), Vector2i(8, 9))
	check(not path.is_empty() and not (Vector2i(6, 9) in path) and not (Vector2i(6, 8) in path),
			"le chemin contourne les cases occupées")
	check(map.find_path(Vector2i(4, 9), Vector2i(8, 9)).size() >= 4, "détour : chemin plus long que la ligne droite")
	_clear_squads()
	path = map.find_path(Vector2i(4, 9), Vector2i(8, 9))
	check(Vector2i(6, 9) in path or Vector2i(6, 8) in path or Vector2i(6, 10) in path, "cases libérées : chemin direct")
