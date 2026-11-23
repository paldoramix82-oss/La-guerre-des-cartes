class_name SimpleAI
extends Node
## IA simple, adversaire de test (demande de l'auteur). Elle joue avec les mêmes règles
## que le joueur, en appelant les mêmes fonctions (construction, recrutement, ordres) :
## - ouvriers : récoltent bois ou baies selon les besoins, construisent ;
## - construction : suit un ordre fixe (cultures, maisons, caserne, ferme...) puis
##   ajoute maisons / cultures / cabanes d'ouvriers selon les besoins ;
## - recrutement : guerriers, archers, cavaliers tant que la nourriture le permet ;
## - armée : nourrie en priorité ; se regroupe près de la base, défend la base, puis
##   attaque (unités, puis bâtiments, du joueur adverse) quand elle est assez grande.
## - mines : l'or ne venant que des mines, l'armée capture la mine la plus proche,
##   l'IA l'exploite (en gardant l'or nécessaire) et y envoie des mineurs.
## Simplification : elle connaît la position des bâtiments adverses (pas de brouillard).

const THINK_INTERVAL := 1.5
## Ordre de construction de départ.
const BUILD_ORDER: Array[StringName] = [
	&"crop", &"worker_hut", &"crop", &"house", &"barracks", &"farm",
	&"worker_hut", &"house", &"crop", &"farm", &"house", &"archer_tower",
]
## Unités recrutées à tour de rôle.
const RECRUIT_MIX: Array[StringName] = [&"warrior", &"archer", &"warrior", &"cavalier", &"archer"]
## Taille de l'armée (individus) pour lancer une attaque, et pour la poursuivre.
const ATTACK_SIZE := 12
const RETREAT_SIZE := 4
## Taille de l'armée (individus) pour partir capturer une mine.
const MINE_ARMY_SIZE := 10
## Distance (cases) autour de la base où un intrus déclenche la défense.
const DEFENSE_RADIUS := 14
## Nourriture minimale gardée avant de recruter.
const FOOD_RESERVE := 30

var team := 1
var enemy_team := 0
var enabled := true
var map: GameMap
var economy: EconomySystem
var attacking := false
var _build_index := 0
var _recruit_index := 0
var _timer := 0.0


func setup(p_map: GameMap, p_economy: EconomySystem, p_team: int = 1) -> SimpleAI:
	map = p_map
	economy = p_economy
	team = p_team
	enemy_team = 1 - team
	return self


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not enabled or map == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = THINK_INTERVAL
	var squads := _my_squads()
	for s in squads:
		s.ration_priority = true  # l'IA choisit de nourrir toutes ses escouades
	_manage_workers(squads)
	_manage_mines(squads)
	_build()
	_recruit()
	_manage_army(squads)


func econ() -> PlayerEconomy:
	return economy.economy(team)


func base() -> Vector2i:
	return map.base_of(team)


func _my_squads() -> Array:
	return get_tree().get_nodes_in_group(Squad.GROUP).filter(
			func(s): return is_instance_valid(s) and s.is_alive() and s.team == team)


# --- Ouvriers ---------------------------------------------------------------------------

func _manage_workers(squads: Array) -> void:
	var sites: Array = []
	for b in economy.buildings_of(team):
		if not b.is_complete:
			sites.append(b)
	sites.append_array(_my_mines().filter(func(m): return m.exploit_started and not m.exploited))
	var e := econ()
	# Ressource voulue : la nourriture d'abord, le bois tant qu'il y a de la place.
	var want := &"forest"
	if e.get_amount(ResourceTypes.FOOD) < 60 or e.is_full(ResourceTypes.WOOD):
		want = &"berries"
	var harvesting := 0
	for s in squads:
		if not s.data.is_worker or s.sheltered:
			continue
		# Un chantier en attente : un ouvrier sur deux y va (les autres continuent de récolter).
		if not sites.is_empty() and s.work_target is Deposit and harvesting % 2 == 1:
			s.order_work(sites[0])
			continue
		if s.work_target is Deposit:
			harvesting += 1
			var res: StringName = s.work_target.data.resource
			if e.is_full(res) or (res == ResourceTypes.WOOD and want == &"berries" and e.get_amount(ResourceTypes.FOOD) < 25):
				_send_to_deposit(s, want)
			continue
		if s.state == Squad.State.IDLE:
			if not sites.is_empty():
				s.order_work(sites[0])
			else:
				_send_to_deposit(s, want)


func _send_to_deposit(s: Squad, want: StringName) -> void:
	var d := _nearest_deposit(s, want)
	if d == null:
		d = _nearest_deposit(s, &"forest" if want == &"berries" else &"berries")
	if d:
		s.order_work(d)


func _nearest_deposit(s: Squad, id: StringName) -> Deposit:
	var best: Deposit = null
	var best_d := INF
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		if o is Deposit and o.is_alive() and o.data.id == id:
			var d := Vector2(o.cell).distance_squared_to(Vector2(s.get_cell()))
			if d < best_d:
				best = o
				best_d = d
	return best


# --- Construction ------------------------------------------------------------------------

func _build() -> void:
	if economy.buildings_of(team).any(func(b): return not b.is_complete):
		return  # un chantier à la fois
	var id := _next_building()
	if id == &"":
		return
	var data := BuildingDatabase.get_building(id)
	if data == null or not econ().can_afford(data.cost) or econ().inhabitants < data.workers:
		return
	if econ().get_amount(ResourceTypes.GOLD) - int(data.cost.get(ResourceTypes.GOLD, 0)) < _gold_reserve():
		return
	var cell := _find_site(data)
	if cell == Vector2i(-1, -1):
		return
	if economy.place_building(data, team, cell, map.get_parent()):
		if _build_index < BUILD_ORDER.size():
			_build_index += 1


## Prochain bâtiment : l'ordre de départ, puis selon les besoins.
func _next_building() -> StringName:
	if _build_index < BUILD_ORDER.size():
		return BUILD_ORDER[_build_index]
	var e := econ()
	if e.inhabitants < 6:
		return &"house"
	if e.last_income.get(ResourceTypes.FOOD, 0) < 10:
		return &"farm" if e.get_amount(ResourceTypes.ORGANIC) >= 6 else &"crop"
	if _count(&"worker_hut") < 5:
		return &"worker_hut"
	return &"house"


func _count(id: StringName) -> int:
	return economy.buildings_of(team).filter(func(b): return b.data.id == id).size()


## Case libre près de la base, en quinconce pour laisser des passages.
func _find_site(data: BuildingData) -> Vector2i:
	var b := base()
	var dir := 1 if team == 0 else -1
	for r in range(3, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r or (dx + dy) % 2 != 0:
					continue
				var c := b + Vector2i(dx * dir, dy)
				if economy.placement_error(data, team, c) == "" and _not_blocking(c):
					return c
	return Vector2i(-1, -1)


## Évite de coller deux bâtiments (garde des passages).
func _not_blocking(c: Vector2i) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if map.object_at(c + d) != null:
			return false
	return true


# --- Recrutement ------------------------------------------------------------------------

func _recruit() -> void:
	if econ().get_amount(ResourceTypes.FOOD) < FOOD_RESERVE:
		return
	# Sans mine productive, garder de quoi en exploiter une.
	if econ().get_amount(ResourceTypes.GOLD) < _gold_reserve() + 100:
		return
	var barracks := economy.buildings_of(team).filter(
			func(b): return b.is_complete and not b.data.recruit_per_turn.is_empty() and b.queue.size() < 2)
	if barracks.is_empty():
		return
	# Des mineurs pour les mines exploitées (3 au plus par mine).
	var needs_miners := _my_mines().any(func(m): return m.exploited and m.assigned_miners() < MineSite.MAX_MINERS)
	var miners_waiting := _my_squads().any(func(sq): return sq.data.can_mine and sq.work_target == null)
	if needs_miners and not miners_waiting and economy.recruit(UnitDatabase.get_unit(&"miner"), team, barracks[0]):
		return
	var unit := UnitDatabase.get_unit(RECRUIT_MIX[_recruit_index % RECRUIT_MIX.size()])
	if economy.recruit(unit, team, barracks[0]):
		_recruit_index += 1


# --- Armée --------------------------------------------------------------------------------

## Or gardé de côté tant qu'aucune mine n'est en exploitation (coût de l'exploitation).
func _gold_reserve() -> int:
	if _my_mines().any(func(m): return m.exploited or m.exploit_started):
		return 0
	return BuildingDatabase.get_building(MineSite.DATA_ID).cost.get(ResourceTypes.GOLD, 0)


func _my_mines() -> Array:
	return get_tree().get_nodes_in_group(MapObject.GROUP).filter(func(o): return o is MineSite and o.team == team)


## Mine à capturer : proche de la base et peu gardée (PV des monstres alentour).
func _mine_to_capture() -> MineSite:
	var best: MineSite = null
	var best_score := INF
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		if o is MineSite and o.team != team:
			var danger := 0
			for n in get_tree().get_nodes_in_group(Individual.GROUP):
				if n.team == GameConfig.MONSTER_TEAM and n.is_alive() and CombatSystem.grid_distance(n.get_cell(), o.cell) <= 14:
					danger += n.hp
			var score := Vector2(o.cell).distance_to(Vector2(base())) + danger / 20.0
			if score < best_score:
				best = o
				best_score = score
	return best


## Exploite les mines capturées ; envoie les mineurs libres dans les mines.
func _manage_mines(squads: Array) -> void:
	for m in _my_mines():
		if m.needs_exploitation():
			economy.start_exploitation(m, team)
	for s in squads:
		if s.data.can_mine and s.work_target == null and s.state == Squad.State.IDLE:
			for m in _my_mines():
				if m.exploited and s.order_work(m):
					break


func _manage_army(squads: Array) -> void:
	var army := squads.filter(func(s): return not s.data.is_worker and not s.data.can_mine \
			and s.data.damage > 0 and s.garrison == null)
	var size := 0
	for s in army:
		size += s.alive_count()
	if not attacking and size >= ATTACK_SIZE and _my_mines().any(func(m): return m.exploited):
		attacking = true
	elif attacking and size <= RETREAT_SIZE:
		attacking = false
	# Défense : un intrus près de la base.
	var intruder := _nearest_enemy_squad(base(), DEFENSE_RADIUS)
	# Pas encore de mine exploitée : l'armée va en capturer une, puis la garde
	# jusqu'à ce que les ouvriers l'aient construite.
	var mine: MineSite = null
	if not _my_mines().any(func(m): return m.exploited) and size >= MINE_ARMY_SIZE:
		var started := _my_mines().filter(func(m): return m.exploit_started)
		mine = started[0] if not started.is_empty() else _mine_to_capture()
	for s in army:
		if s.state == Squad.State.ACTING:
			continue
		if intruder:
			s.order_target(intruder)
		elif mine:
			# Nettoie la mine et la route depuis la base (ennemis et monstres), pour que
			# les ouvriers puissent y aller sans fuir.
			var near := _nearest_hostile_squad(mine.cell, 10)
			if near == null:
				near = _route_threat(mine)
			if near:
				s.order_target(near)
			elif s.state == Squad.State.IDLE and (CombatSystem.grid_distance(s.get_cell(), mine.cell) > GameConfig.MINE_CAPTURE_RADIUS
					or CombatSystem.grid_distance(s.get_cell(), mine.cell) < 2):
				# Garde à 2-3 cases : laisse la place autour de la mine aux ouvriers.
				var away := Vector2(base() - mine.cell).normalized() * 3.0
				s.order_move(mine.cell + Vector2i(roundi(away.x), roundi(away.y)))
		elif attacking:
			_attack_step(s)
		elif s.state == Squad.State.IDLE and CombatSystem.grid_distance(s.get_cell(), _rally()) > 4:
			s.order_move(_rally())


func _rally() -> Vector2i:
	return base() + Vector2i(6 if team == 0 else -6, 0)


func _attack_step(s: Squad) -> void:
	var target := _nearest_enemy_squad(s.get_cell(), 10)
	if target:
		s.order_target(target)
		return
	var b := _nearest_enemy_building(s.get_cell())
	if b:
		if not s.order_attack_building(b):
			s.order_move(b.cell)
		return
	if s.state == Squad.State.IDLE:
		s.order_move(map.base_of(enemy_team))


func _nearest_enemy_squad(from: Vector2i, radius: int) -> Squad:
	var best: Squad = null
	var best_d := radius + 1
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var o := n as Individual
		if o == null or not o.is_alive() or o.team != enemy_team or o.squad.sheltered:
			continue
		var d := CombatSystem.grid_distance(from, o.get_cell())
		if d < best_d:
			best = o.squad
			best_d = d
	return best


## Escouade hostile (adversaire ou monstre) la plus proche de `from`.
func _nearest_hostile_squad(from: Vector2i, radius: int) -> Squad:
	var best: Squad = null
	var best_d := radius + 1
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var o := n as Individual
		if o == null or not o.is_alive() or o.team == team or o.squad.sheltered:
			continue
		var d := CombatSystem.grid_distance(from, o.get_cell())
		if d < best_d:
			best = o.squad
			best_d = d
	return best


## Escouade hostile près du chemin réel base -> mine (la plus proche de la base) :
## les ouvriers la croiseraient et fuiraient.
func _route_threat(mine: MineSite) -> Squad:
	var route := map.find_path(base(), mine.cell)
	var best: Squad = null
	var best_i := 1 << 30
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var o := n as Individual
		if o == null or not o.is_alive() or o.team == team or o.squad.sheltered:
			continue
		var oc := o.get_cell()
		for i in range(0, route.size(), 2):
			if CombatSystem.grid_distance(oc, route[i]) <= 7:
				if i < best_i:
					best = o.squad
					best_i = i
				break
	return best


func _nearest_enemy_building(from: Vector2i) -> Building:
	var best: Building = null
	var best_d := INF
	for b in economy.buildings_of(enemy_team):
		if b.is_attackable():
			var d := Vector2(b.cell).distance_squared_to(Vector2(from))
			if d < best_d:
				best = b
				best_d = d
	return best
