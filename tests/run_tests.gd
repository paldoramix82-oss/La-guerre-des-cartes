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
	_test_squad_totals()
	_test_individual_damage_and_removal()
	_test_squad_destruction()
	_test_range()
	_test_area_patterns()
	_test_cavalier_circle_hits_multiple()
	_test_pathfinding_avoids_water()
	_test_movement_speed()
	_test_attack_order_chases_and_kills()
	_test_mage_burn()
	_test_burn_refresh()
	_test_heal()
	_test_healer_auto_heals_and_never_attacks()
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


func spawn(id: StringName, team: int, cell: Vector2i) -> Squad:
	var s := Squad.new().setup(UnitDatabase.get_unit(id), team, map, cell)
	root.add_child(s)
	return s


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


func _test_squad_totals() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5))
	check(w.total_hp() == 200, "4 guerriers = 200 PV")
	check(w.alive_count() * w.data.damage == 40, "4 guerriers = 40 dégâts")
	_clear_squads()


func _test_individual_damage_and_removal() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5))
	var a := spawn(&"archer", 1, Vector2i(6, 5))
	CombatSystem.perform_attack(w, a, get_nodes_in_group(Squad.GROUP))
	# 4 coups de 10 : premier archer (30 PV) meurt après 3 coups, le 4e touche le second.
	check(a.alive_count() == 1, "un archer retiré de l'escouade")
	check(a.total_hp() == 20, "archer restant à 20 PV")
	_clear_squads()


func _test_squad_destruction() -> void:
	var w := spawn(&"warrior", 0, Vector2i(5, 5))
	var m := spawn(&"mage", 1, Vector2i(6, 5))
	var destroyed := [false]
	m.destroyed.connect(func(_s): destroyed[0] = true)
	CombatSystem.perform_attack(w, m, get_nodes_in_group(Squad.GROUP))
	check(destroyed[0], "escouade détruite quand tous les individus meurent")
	check(not m.is_alive(), "mage mort")
	_clear_squads()


func _test_range() -> void:
	var a := spawn(&"archer", 0, Vector2i(5, 5))
	var near := spawn(&"warrior", 1, Vector2i(8, 7))
	var far := spawn(&"warrior", 1, Vector2i(9, 5))
	check(CombatSystem.in_range(a, near), "archer : cible à 3 cases à portée")
	check(not CombatSystem.in_range(a, far), "archer : cible à 4 cases hors portée")
	_clear_squads()


func _test_area_patterns() -> void:
	var mage := UnitDatabase.get_unit(&"mage")
	check(CombatSystem.affected_cells(mage, Vector2i(0, 0), Vector2i(1, 0)) == [Vector2i(1, 0), Vector2i(2, 0)],
			"mage : 2 cases horizontales")
	check(CombatSystem.affected_cells(mage, Vector2i(0, 0), Vector2i(0, -1)) == [Vector2i(0, -1), Vector2i(0, -2)],
			"mage : 2 cases verticales")
	var cav := UnitDatabase.get_unit(&"cavalier")
	check(CombatSystem.affected_cells(cav, Vector2i(5, 5), Vector2i(6, 5)).size() == 9, "cavalier : cercle de rayon 1")


func _test_cavalier_circle_hits_multiple() -> void:
	var c := spawn(&"cavalier", 0, Vector2i(10, 10))
	var e1 := spawn(&"warrior", 1, Vector2i(11, 10))
	var e2 := spawn(&"warrior", 1, Vector2i(9, 11))
	var e3 := spawn(&"warrior", 1, Vector2i(13, 10))
	var ally := spawn(&"warrior", 0, Vector2i(10, 11))
	CombatSystem.perform_attack(c, e1, get_nodes_in_group(Squad.GROUP))
	check(e1.total_hp() == 170 and e2.total_hp() == 170, "cavalier touche les deux ennemis adjacents (2x15)")
	check(e3.total_hp() == 200, "cavalier ne touche pas un ennemi hors cercle")
	check(ally.total_hp() == 200, "pas de tir allié")
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
	var c := spawn(&"cavalier", 0, Vector2i(2, 2))
	c.order_move(Vector2i(6, 2))
	var t := 0.0
	while c.state == Squad.State.MOVING and t < 10.0:
		c.tick(0.05)
		t += 0.05
	check(c.get_cell() == Vector2i(6, 2), "cavalier arrivé à destination")
	check(absf(t - GameConfig.SECONDS_PER_TURN) < 0.11, "cavalier : 4 cases en 1 tour (%.2fs)" % t)
	_clear_squads()


func _test_attack_order_chases_and_kills() -> void:
	var w := spawn(&"warrior", 0, Vector2i(2, 10))
	var m := spawn(&"mage", 1, Vector2i(7, 10))
	m.state = Squad.State.IDLE
	w.order_target(m)
	var t := 0.0
	while is_instance_valid(m) and m.is_alive() and t < 20.0:
		w.tick(0.05)
		t += 0.05
	check(not m.is_alive(), "le guerrier rejoint et élimine le mage")
	check(w.total_hp() == 200 or w.alive_count() == 4, "guerrier intact (le mage n'a pas été simulé)")
	_clear_squads()


func _run_ticks(squads: Array, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		for s in squads:
			if is_instance_valid(s):
				s.tick(0.05)
		t += 0.05


func _test_mage_burn() -> void:
	var m := spawn(&"mage", 0, Vector2i(5, 5))
	var w := spawn(&"warrior", 1, Vector2i(6, 5))
	CombatSystem.perform_attack(m, w, get_nodes_in_group(Squad.GROUP))
	check(w.total_hp() == 190, "mage : 10 dégâts immédiats")
	check(w.is_burning(), "mage : la cible brûle")
	w.state = Squad.State.MOVING  # empêche la riposte automatique pendant le test
	_run_ticks([w], GameConfig.SECONDS_PER_TURN)
	check(w.total_hp() == 188, "brûlure : 2 dégâts au 1er tour (%d)" % w.total_hp())
	_run_ticks([w], GameConfig.SECONDS_PER_TURN)
	check(w.total_hp() == 186, "brûlure : 2 dégâts au 2e tour (%d)" % w.total_hp())
	_run_ticks([w], GameConfig.SECONDS_PER_TURN * 2)
	check(w.total_hp() == 186 and not w.is_burning(), "brûlure terminée après 2 tours")
	_clear_squads()


func _test_burn_refresh() -> void:
	var m := spawn(&"mage", 0, Vector2i(5, 5))
	var w := spawn(&"warrior", 1, Vector2i(6, 5))
	w.state = Squad.State.MOVING
	CombatSystem.perform_attack(m, w, get_nodes_in_group(Squad.GROUP))
	CombatSystem.perform_attack(m, w, get_nodes_in_group(Squad.GROUP))
	check(w.burns.size() == 1, "deux brûlures du mage ne se cumulent pas")
	_run_ticks([w], GameConfig.SECONDS_PER_TURN * 3)
	check(w.total_hp() == 200 - 20 - 4, "brûlure renouvelée : 2 tours seulement (%d)" % w.total_hp())
	_clear_squads()


func _test_heal() -> void:
	var h := spawn(&"healer", 0, Vector2i(5, 5))
	var w := spawn(&"warrior", 0, Vector2i(7, 5))
	var enemy := spawn(&"warrior", 1, Vector2i(8, 5))
	w.member_hp = [50, 42, 30]  # un guerrier déjà mort, deux blessés
	enemy.member_hp = [40, 50, 50, 50]
	CombatSystem.perform_heal(h, w, get_nodes_in_group(Squad.GROUP))
	check(w.member_hp == [50, 42, 35], "soin : +5 PV sur l'individu le plus blessé")
	check(w.alive_count() == 3, "soin : pas de résurrection")
	check(enemy.total_hp() == 190, "soin : les ennemis de la zone ne sont pas soignés")
	w.member_hp = [50, 48]
	CombatSystem.perform_heal(h, w, get_nodes_in_group(Squad.GROUP))
	check(w.member_hp == [50, 50], "soin : plafonné aux PV max")
	check(not CombatSystem.can_target(h, enemy), "soigneur : ne cible pas un ennemi")
	check(not w.order_target(h) or w.team != h.team, "guerrier : ne cible pas un allié")
	_clear_squads()


func _test_healer_auto_heals_and_never_attacks() -> void:
	var h := spawn(&"healer", 0, Vector2i(5, 5))
	var w := spawn(&"warrior", 0, Vector2i(6, 5))
	var enemy := spawn(&"archer", 1, Vector2i(7, 5))
	enemy.state = Squad.State.MOVING  # immobile et passif
	w.state = Squad.State.MOVING
	w.member_hp = [50, 50, 50, 20]
	_run_ticks([h], GameConfig.SECONDS_PER_TURN * 3)
	check(w.total_hp() > 170, "soigneur inactif : soigne automatiquement un allié blessé")
	check(enemy.total_hp() == 60, "soigneur : n'attaque jamais")
	_clear_squads()


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
