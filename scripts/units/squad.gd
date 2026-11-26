class_name Squad
extends Node2D
## Escouade : entité contrôlable unique composée de plusieurs individus (GDD §5).
## Chaque individu (Individual) occupe sa propre case ; l'escouade reçoit les ordres
## et les répartit entre ses individus. Les statistiques proviennent d'un UnitData.

signal members_changed(squad: Squad)
signal destroyed(squad: Squad)

## ACTING = attaque (ennemi) ou soin (allié) selon `data.action`.
## WORKING = ouvrier qui récolte un gisement ou construit un bâtiment.
enum State { IDLE, MOVING, ACTING, WORKING }

## Rayon (cases) dans lequel un ouvrier cherche un gisement du même type quand le sien est épuisé.
const NEXT_DEPOSIT_RADIUS := 10

const GROUP := &"squads"
## Fréquence de recherche automatique de cible quand l'escouade est inactive (s).
const AUTO_ACQUIRE_INTERVAL := 0.2

var data: UnitData
var team: int = 0
var map: GameMap
var members: Array[Individual] = []

var state: State = State.IDLE
var target: Squad = null
## Cible acquise automatiquement (sans ordre du joueur) : poursuite limitée.
var _auto_target := false
## Case où l'escouade s'est engagée d'elle-même.
var _anchor := Vector2i.ZERO
## Poursuite automatique : la cible peut s'éloigner jusqu'à vision + AUTO_LEASH cases du point d'engagement.
const AUTO_LEASH := 4
var _acquire_timer := 0.0
## Cabane Garde à laquelle l'escouade est affectée, ou null.
var garrison: Building = null
## Bâtiment ennemi attaqué, ou null.
var target_building: Building = null
## Objet travaillé (gisement ou chantier).
var work_target: MapObject = null
## Type du dernier gisement récolté (pour enchaîner sur un gisement voisin).
var _last_deposit_type: StringName = &""
## Cabane d'origine des ouvriers : s'ils ne sont pas nourris, ils ne travaillent pas.
var home: Building = null
## Consommation de nourriture payée ce tour-ci (voir EconomySystem).
var fed := true
## Choisie avec le bouton « Nourrir » : servie en priorité, et seule servie en rationnement.
var ration_priority := false

# --- Ouvriers : abri pendant les combats (décision de l'auteur) ---
## Intervalle de vérification de la menace (s).
const THREAT_CHECK_INTERVAL := 0.3
## [PROVISOIRE] Secondes sans ennemi en vue avant de ressortir de la cabane.
const SAFE_DELAY := 5.0
## Caché dans sa cabane : invisible, ne peut pas être ciblé.
var sheltered := false
var _fleeing := false
var _resume_target: MapObject = null
var _threat_timer := 0.0
var _safe_time := 0.0

var selected := false:
	set(value):
		selected = value
		for m in members:
			if is_instance_valid(m):
				m.queue_redraw()


## Crée l'escouade et place ses individus autour de `cell`, une case chacun
## (ou exactement sur `cells` si fourni).
func setup(p_data: UnitData, p_team: int, p_map: GameMap, cell: Vector2i, cells: Array = []) -> Squad:
	data = p_data
	team = p_team
	map = p_map
	name = "%s_%d" % [data.id, get_instance_id()]
	if cells.is_empty():
		cells = map.spread_cells(cell, data.squad_size)
	for i in mini(data.squad_size, cells.size()):
		var m := Individual.new()
		m.squad = self
		m.hp = data.hp
		m.name = "%s_%d" % [data.id, i]
		add_child(m)
		m.place(cells[i])
		members.append(m)
	return self


func _enter_tree() -> void:
	add_to_group(GROUP)


# --- État -------------------------------------------------------------------

func alive_count() -> int:
	return members.size()


func is_alive() -> bool:
	return not members.is_empty()


func total_hp() -> int:
	var t := 0
	for m in members:
		t += m.hp
	return t


func max_total_hp() -> int:
	return data.max_total_hp()


func is_wounded() -> bool:
	return members.any(func(m): return m.is_wounded())


## Faux si la consommation de l'escouade (ou de la cabane de l'ouvrier) n'a pas été payée :
## l'escouade s'arrête alors de fonctionner.
func is_fed() -> bool:
	return fed and (not is_instance_valid(home) or home.fed)


func set_fed(value: bool) -> void:
	if fed != value:
		fed = value
		for m in members:
			m.queue_redraw()


func is_burning() -> bool:
	return members.any(func(m): return m.is_burning())


## Centre de l'escouade (moyenne des positions des individus).
func center() -> Vector2:
	if members.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for m in members:
		sum += m.position
	return sum / members.size()


func get_cell() -> Vector2i:
	return map.world_to_cell(center())


func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for m in members:
		out.append(m.get_cell())
	return out


# --- Ordres -----------------------------------------------------------------

## Déplace l'escouade vers `cell` : chaque individu reçoit une case libre autour.
func order_move(cell: Vector2i) -> void:
	order_move_cells(map.spread_cells(cell, members.size(), members))


## Déplace les individus sur les cases données (attribution au plus proche).
func order_move_cells(dest_cells: Array) -> void:
	target = null
	work_target = null
	target_building = null
	_auto_target = false
	var remaining := dest_cells.duplicate()
	for m in members:
		m.target = null
		if remaining.is_empty():
			m.stop()
			continue
		var best := 0
		for i in remaining.size():
			if m.position.distance_squared_to(map.cell_to_world(remaining[i])) \
					< m.position.distance_squared_to(map.cell_to_world(remaining[best])):
				best = i
		m.move_to(remaining[best])
		remaining.remove_at(best)
	state = State.MOVING if members.any(func(m): return m.is_moving()) else State.IDLE


## Attaque (ennemi) ou soigne (allié) l'escouade `other` selon l'action de l'unité.
## Retourne false si cette escouade ne peut pas agir sur `other`.
func order_target(other) -> bool:
	if not CombatSystem.can_target(self, other):
		return false
	target_building = null
	target = other
	_auto_target = false
	state = State.ACTING
	return true


## Attaque le bâtiment ennemi `b` (bâtiments avec PV seulement).
func order_attack_building(b) -> bool:
	if not is_instance_valid(b) or not (b is Building) or b.team == team or not b.is_attackable():
		return false
	if data.action != UnitData.ActionType.ATTACK or data.damage <= 0:
		return false
	target = null
	work_target = null
	_auto_target = false
	target_building = b
	for m in members:
		m.target = null
	state = State.ACTING
	return true


## Ouvriers : récolter le gisement / construire le chantier `obj`.
func order_work(obj) -> bool:
	if not is_instance_valid(obj) or not (obj is MapObject) or not obj.can_be_worked_by(self):
		return false
	target = null
	_auto_target = false
	work_target = obj
	if obj is Deposit:
		_last_deposit_type = obj.data.id
	for m in members:
		m.target = null
	state = State.WORKING
	return true


## Placer l'escouade dans une Cabane Garde.
func order_garrison(b) -> bool:
	if not is_instance_valid(b) or not (b is Building) or b.garrison == null:
		return false
	return b.garrison.send(self)


## Quitter sa Cabane Garde (l'escouade redevient libre).
func leave_garrison() -> void:
	if is_instance_valid(garrison) and garrison.garrison:
		garrison.garrison.squads.erase(self)
	garrison = null
	sheltered = false
	for m in members:
		m.visible = true


func order_stop() -> void:
	work_target = null
	target_building = null
	target = null
	_auto_target = false
	for m in members:
		m.target = null
		if m.is_moving():
			m.stop()
	state = State.IDLE


# --- Simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)


## Avance la simulation de `delta` secondes (appelable directement par les tests).
func tick(delta: float) -> void:
	for m in members.duplicate():
		if is_instance_valid(m) and m.is_alive():
			m.tick(delta)
	if not is_alive() or not is_fed():
		return
	# Dans une Cabane Garde : la cabane décide quand sortir.
	if sheltered and garrison != null:
		return
	# Unités à distance : garder ses distances (sauf déplacement ordonné par le joueur).
	if data.attack_range >= 2 and state != State.MOVING:
		for m in members:
			if is_instance_valid(m) and m.is_alive():
				m.keep_distance(delta)
	if data.is_worker:
		_threat_timer -= delta
		if _threat_timer <= 0.0:
			_threat_timer = THREAT_CHECK_INTERVAL
			_update_shelter(THREAT_CHECK_INTERVAL)
		if sheltered:
			return
	match state:
		State.IDLE:
			_acquire_timer -= delta
			if _acquire_timer <= 0.0:
				_acquire_timer = AUTO_ACQUIRE_INTERVAL
				_auto_acquire()
		State.MOVING:
			if not members.any(func(m): return m.is_moving()):
				state = State.IDLE
		State.ACTING:
			_process_action(delta)
		State.WORKING:
			_process_work(delta)


func _process_action(delta: float) -> void:
	if target_building != null:
		if not is_instance_valid(target_building) or not target_building.is_attackable():
			order_stop()
			return
		for m in members.duplicate():
			if is_instance_valid(m) and m.is_alive():
				m.update_siege(delta, target_building)
		return
	if not CombatSystem.can_target(self, target) \
			or (data.action == UnitData.ActionType.HEAL and not target.is_wounded()):
		order_stop()
		return
	var target_squad = target
	# Tous les individus vont au contact (ou à portée), même pour une cible choisie seuls.
	for m in members.duplicate():
		if is_instance_valid(m) and m.is_alive():
			m.update_action(delta, target_squad, true)
	if _auto_target and _beyond_leash():
		order_stop()


## Cible automatique trop loin du point d'engagement : on abandonne la poursuite.
func _beyond_leash() -> bool:
	if not is_instance_valid(target):
		return true
	var limit := data.vision_range() + AUTO_LEASH
	for m in target.members:
		if is_instance_valid(m) and CombatSystem.grid_distance(m.get_cell(), _anchor) <= limit:
			return false
	return true


## Prend `other` pour cible de lui-même (riposte, ennemi en vue).
func _engage(other) -> void:
	if order_target(other):
		_auto_target = true
		_anchor = get_cell()


## Un individu de l'escouade est frappé : l'escouade riposte si elle n'a rien de mieux
## à faire (au repos, ou cible automatique hors d'atteinte).
func on_attacked(attacker) -> void:
	if data.is_worker or sheltered or not is_instance_valid(attacker) or not CombatSystem.can_target(self, attacker):
		return
	if state == State.IDLE:
		_engage(attacker)
	elif state == State.ACTING and _auto_target and target != attacker \
			and not members.any(func(m): return is_instance_valid(m.target) and CombatSystem.in_range(m, m.target)):
		_engage(attacker)


func _process_work(delta: float) -> void:
	if not is_instance_valid(work_target) or not work_target.can_be_worked_by(self):
		var was_deposit := _last_deposit_type != &"" and not is_instance_valid(work_target)
		order_stop()
		if was_deposit:
			_work_next_deposit()
		return
	var can_work := is_fed()
	for m in members.duplicate():
		if is_instance_valid(m) and m.is_alive():
			m.update_work(delta, work_target, can_work)


## Gisement épuisé : passe au gisement du même type le plus proche, s'il y en a un.
func _work_next_deposit() -> void:
	var best: Deposit = null
	var best_d := NEXT_DEPOSIT_RADIUS + 1
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		if o is Deposit and o.is_alive() and o.data.id == _last_deposit_type:
			var d := CombatSystem.grid_distance(get_cell(), o.cell)
			if d < best_d:
				best = o
				best_d = d
	if best:
		order_work(best)


## Escouade inactive : agit sur l'escouade (ennemi en vue, ou allié blessé en vue pour le
## soin) ;  dont un individu valide est à portée
## d'un de ses individus (ennemi pour l'attaque, allié blessé pour le soin), sans poursuite.
func _auto_acquire() -> void:
	if not is_inside_tree():
		return
	if data.is_worker:
		if not _fleeing:
			_auto_build()
		return
	var best: Squad = null
	var best_d := 1 << 30
	for other in get_tree().get_nodes_in_group(Individual.GROUP):
		var o := other as Individual
		if o == null or not o.is_alive() or o.squad.sheltered or not CombatSystem.can_target(self, o.squad):
			continue
		if data.action == UnitData.ActionType.HEAL and not o.is_wounded():
			continue
		# Un ennemi dans la vision de l'escouade (et plus seulement à portée d'attaque).
		for m in members:
			var d := CombatSystem.grid_distance(m.get_cell(), o.get_cell())
			if d <= maxi(data.vision_range(), data.attack_range) and d < best_d:
				best = o.squad
				best_d = d
	if best:
		_engage(best)


# --- Ouvriers -------------------------------------------------------------------------

## Ouvrier libre : part de lui-même vers le chantier de son camp le plus proche.
func _auto_build() -> void:
	var best: MapObject = null
	var best_d := INF
	for o in get_tree().get_nodes_in_group(MapObject.GROUP):
		if (o is Building or o is MineSite) and o.can_be_worked_by(self):
			var d := center().distance_squared_to(o.position)
			if d < best_d:
				best = o
				best_d = d
	if best:
		order_work(best)


## Un individu hostile (autre camp, monstre) est-il à portée de vue de l'ouvrier ?
func _threat_near() -> bool:
	var vision := int(data.move_speed) + GameConfig.VISION_BONUS
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var o := n as Individual
		if o == null or o.team == team or not o.is_alive() or o.squad.sheltered:
			continue
		for m in members:
			if CombatSystem.grid_distance(m.get_cell(), o.get_cell()) <= vision:
				return true
	return false


## Combat proche : l'ouvrier court se cacher dans sa cabane, puis ressort et reprend
## son travail quand plus aucun ennemi n'est en vue depuis SAFE_DELAY secondes.
func _update_shelter(dt: float) -> void:
	var threat := _threat_near()
	if sheltered:
		_safe_time = 0.0 if threat else _safe_time + dt
		if _safe_time >= SAFE_DELAY:
			_leave_shelter()
		return
	if not is_instance_valid(home):
		return
	if threat and not _fleeing:
		_fleeing = true
		if is_instance_valid(work_target):
			_resume_target = work_target
		var cells := map.spread_cells(home.cell, 1, members)
		if not cells.is_empty():
			order_move_cells(cells)
	# Une fois partie, la fuite va jusqu'à la cabane.
	if _fleeing and members.all(func(m): return not m.is_moving() and CombatSystem.grid_distance(m.get_cell(), home.cell) <= 1):
		_enter_shelter()


func _enter_shelter() -> void:
	sheltered = true
	_fleeing = false
	_safe_time = 0.0
	for m in members:
		m.path.clear()
		m.visible = false


func _leave_shelter() -> void:
	sheltered = false
	for m in members:
		m.visible = true
	_resume_work()


func _resume_work() -> void:
	var t := _resume_target
	_resume_target = null
	if is_instance_valid(t) and order_work(t):
		return
	order_stop()


func on_member_died(m: Individual) -> void:
	members.erase(m)
	members_changed.emit(self)
	if members.is_empty():
		destroyed.emit(self)
		queue_free()
