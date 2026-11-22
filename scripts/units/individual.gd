class_name Individual
extends Node2D
## Un individu d'une escouade (GDD §5.1). Chaque individu occupe sa propre case,
## possède ses PV, se déplace et agit (attaque ou soin) depuis sa case.
## Il est piloté par son escouade (Squad) : il n'a pas de _physics_process propre.

const GROUP := &"individuals"
const NO_CELL := Vector2i(-1, -1)

var squad: Squad
var hp: int = 0
var path: Array[Vector2i] = []
## Case réservée (case occupée à l'arrêt, ou destination en cours).
var reserved_cell := NO_CELL
## Individu visé (ennemi pour l'attaque, allié pour le soin).
var target: Individual = null
## Brûlures actives, par individu source (id) : {damage, seconds_left, timer, team}.
var burns: Dictionary = {}
## Camp de l'auteur du dernier coup reçu (récompense des monstres au tueur).
var last_attacker_team: int = -1

var _cooldown := 0.0
# --- Animation (purement visuelle) ---
const LUNGE_DURATION := 0.22
const LUNGE_DISTANCE := 7.0
const WORK_SWING_INTERVAL := 0.5
var _anim_time := 0.0
var _lunge_t := 0.0
var _lunge_dir := Vector2.ZERO
## 1 = regarde à droite, -1 = à gauche.
var _facing := 1.0
var _work_swing := 0.0
var _repath_timer := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE

var data: UnitData:
	get:
		return squad.data
var team: int:
	get:
		return squad.team
var map: GameMap:
	get:
		return squad.map


func _enter_tree() -> void:
	add_to_group(GROUP)


func _exit_tree() -> void:
	_release()


# --- État -------------------------------------------------------------------

func get_cell() -> Vector2i:
	return map.world_to_cell(position)


func is_alive() -> bool:
	return hp > 0


func is_wounded() -> bool:
	return is_alive() and hp < data.hp


func is_moving() -> bool:
	return not path.is_empty()


func is_burning() -> bool:
	return not burns.is_empty()


# --- Placement et déplacement ------------------------------------------------

## Place l'individu directement sur `cell`.
func place(cell: Vector2i) -> void:
	_facing = -1.0 if team == 1 else 1.0
	position = map.cell_to_world(cell)
	path.clear()
	_reserve(cell)


## Se rend sur `cell` (la case est réservée dès maintenant).
func move_to(cell: Vector2i) -> void:
	_reserve(cell)
	path = map.find_path(get_cell(), cell)


## S'arrête sur la case libre la plus proche de sa position actuelle.
func stop() -> void:
	path.clear()
	var here := get_cell()
	if map.is_free(here, self):
		_reserve(here)
	else:
		var cells := map.spread_cells(here, 1, [self])
		move_to(cells[0] if not cells.is_empty() else here)


func _reserve(cell: Vector2i) -> void:
	_release()
	reserved_cell = cell
	map.reserve(cell, self)


func _release() -> void:
	if reserved_cell != NO_CELL and squad and squad.map:
		map.release(reserved_cell, self)
	reserved_cell = NO_CELL


# --- Dégâts, soins, brûlure ---------------------------------------------------

func take_damage(amount: int, text_color: Color = Color(1, 0.4, 0.35)) -> void:
	if not is_alive() or amount <= 0:
		return
	hp -= amount
	_flash_hit(Color.WHITE)
	Effects.floating_text(self, position, "-%d" % amount, text_color)
	if hp <= 0:
		Effects.burst(self, [position], Color(0.85, 0.85, 0.85))
		_die()


func heal(amount: int) -> void:
	if not is_alive() or amount <= 0:
		return
	var healed := mini(data.hp, hp + amount) - hp
	hp += healed
	_flash_hit(Color(0.5, 1, 0.5))
	if healed > 0:
		Effects.floating_text(self, position, "+%d" % healed, Color(0.5, 1, 0.5))


## Applique une brûlure : `damage` dégâts par seconde pendant `seconds` secondes.
## Une nouvelle brûlure de la même source relance la durée ; des sources différentes
## (deux Mages) se cumulent (décision de l'auteur).
func apply_burn(source: int, damage: int, seconds: float, source_team: int = -1) -> void:
	if burns.has(source):
		burns[source].seconds_left = seconds
	else:
		burns[source] = {"damage": damage, "seconds_left": seconds, "timer": 1.0, "team": source_team}


func _die() -> void:
	_give_loot()
	hp = 0
	path.clear()
	_release()
	remove_from_group(GROUP)
	squad.on_member_died(self)
	queue_free()


## Monstre tué : sa récompense va au joueur qui a porté le dernier coup.
func _give_loot() -> void:
	if data.loot.is_empty() or last_attacker_team < 0 or last_attacker_team > 1 or not is_inside_tree():
		return
	var eco := get_tree().get_first_node_in_group(EconomySystem.GROUP) as EconomySystem
	if eco == null:
		return
	eco.economy(last_attacker_team).add_all(data.loot)
	Effects.floating_text(self, position + Vector2(0, -12), "+" + ResourceTypes.format(data.loot), Color(1, 0.85, 0.35))


func _flash_hit(color: Color) -> void:
	_flash = 0.15
	_flash_color = color
	queue_redraw()


# --- Simulation (appelée par l'escouade) --------------------------------------

## Brûlures, déplacement, effets visuels.
func tick(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _lunge_t > 0.0:
		_lunge_t = maxf(0.0, _lunge_t - delta)
		queue_redraw()
	if is_moving() and squad.is_fed():
		_anim_time += delta
		queue_redraw()
	elif _anim_time != 0.0:
		_anim_time = 0.0
		queue_redraw()
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	_process_burns(delta)
	# Sans nourriture, l'individu ne bouge plus (GDD §3.2, décision de l'auteur).
	if is_alive() and squad.is_fed():
		_follow_path(delta)
		if not is_moving():
			_snap_to_cell(delta)


## Agit sur l'escouade `target_squad`. Si `chase`, se rapproche des cibles hors de portée.
## Retourne true si l'individu a une cible à portée.
func update_action(delta: float, target_squad, chase: bool) -> bool:
	if not _is_valid_target(target):
		target = null
	# Préférer une cible à portée ; sinon (poursuite) la plus proche.
	if target == null or not CombatSystem.in_range(self, target):
		var t := _pick_target(target_squad, chase)
		if t:
			target = t
	if target == null:
		return false
	if CombatSystem.in_range(self, target):
		# Ne s'arrête que sur une case qui lui est disponible.
		if is_moving() and map.is_free(get_cell(), self):
			path.clear()
			_reserve(get_cell())
		if not is_moving() and _cooldown <= 0.0:
			var t := target
			var touched := CombatSystem.perform_action(self, t)
			_play_action_fx(t, touched)
			_cooldown = data.attack_interval
		return true
	if chase:
		_repath_timer -= delta
		if _repath_timer <= 0.0 or not is_moving():
			_repath_timer = GameConfig.REPATH_INTERVAL
			_approach(target)
	return false


## Ouvrier : rejoint une case adjacente à `obj` puis y travaille (si nourri).
func update_work(delta: float, obj: MapObject, fed: bool) -> void:
	var adjacent := CombatSystem.grid_distance(get_cell(), obj.cell) == 1
	if adjacent:
		if is_moving() and map.is_free(get_cell(), self):
			path.clear()
			_reserve(get_cell())
		if not is_moving() and fed:
			obj.work(self, delta)
			_work_swing -= delta
			if _work_swing <= 0.0:
				_work_swing = WORK_SWING_INTERVAL
				_face(obj.position)
				_start_lunge(obj.position)
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0 or not is_moving():
		_repath_timer = GameConfig.REPATH_INTERVAL
		var dest := map.free_cell_in_range(obj.cell, 1, get_cell(), self)
		if dest != NO_CELL and (dest != reserved_cell or not is_moving()):
			move_to(dest)


## Cible valide à portée la plus proche dans `squad_ref` (ou la plus proche tout court si `allow_far`).
func _pick_target(squad_ref, allow_far: bool) -> Individual:
	if not is_instance_valid(squad_ref):
		return null
	var best: Individual = null
	var best_d := INF
	var best_in_range := false
	for m in squad_ref.members:
		if not _is_valid_target(m):
			continue
		var in_r := CombatSystem.in_range(self, m)
		if not in_r and not allow_far:
			continue
		var d := position.distance_squared_to(m.position)
		if (in_r and not best_in_range) or (in_r == best_in_range and d < best_d):
			best = m
			best_d = d
			best_in_range = in_r
	return best


## `m` n'est pas typé : il peut s'agir d'un individu mort et déjà libéré.
func _is_valid_target(m) -> bool:
	if not is_instance_valid(m) or not (m is Individual) or not m.is_alive() or m.squad.sheltered:
		return false
	if data.action == UnitData.ActionType.HEAL:
		return m.team == team and m.is_wounded()
	return m.team != team


## Se rend sur une case libre à portée de `t`, la plus proche.
func _approach(t: Individual) -> void:
	var dest := map.free_cell_in_range(t.get_cell(), data.attack_range, get_cell(), self)
	if dest == NO_CELL:
		dest = map.nearest_walkable(t.get_cell())
	if dest != reserved_cell or not is_moving():
		move_to(dest)


# --- Effets visuels -------------------------------------------------------------------

## Montre qui agit sur qui : projectile (Archer, Mage, Soigneur) ou élan (corps à corps).
func _play_action_fx(t: Individual, touched: Array) -> void:
	if not is_instance_valid(t):
		return
	_face(t.position)
	if data.projectile:
		var up := Vector2(0, -6)
		Effects.projectile(self, position + up, t.position + up, data.projectile, data.projectile_color, data.projectile_angle)
		if data.attack_pattern != UnitData.AttackPattern.SINGLE:
			var cells := CombatSystem.affected_cells(data, get_cell(), t.get_cell())
			Effects.burst(self, cells.map(func(c): return map.cell_to_world(c)), data.projectile_color)
	else:
		_start_lunge(t.position)
		if data.attack_pattern == UnitData.AttackPattern.CIRCLE:
			Effects.burst(self, [position], Color(1, 0.85, 0.5))


func _start_lunge(toward: Vector2) -> void:
	_lunge_dir = (toward - position).normalized()
	_lunge_t = LUNGE_DURATION
	queue_redraw()


func _face(toward: Vector2) -> void:
	var dx := toward.x - position.x
	if absf(dx) > 1.0:
		var f := signf(dx)
		if f != _facing:
			_facing = f
			queue_redraw()


func _process_burns(delta: float) -> void:
	for source in burns.keys():
		var b: Dictionary = burns[source]
		b.timer -= delta
		b.seconds_left -= delta
		if b.timer <= 0.0:
			b.timer += 1.0
			last_attacker_team = b.team
			take_damage(b.damage, Color(1, 0.6, 0.2))
			if not is_alive():
				return
		if b.seconds_left <= 0.001:
			burns.erase(source)


func _follow_path(delta: float) -> void:
	var step := GameConfig.move_speed_px(data.move_speed) * delta
	while step > 0.0 and not path.is_empty():
		var dest := map.cell_to_world(path[0])
		_face(dest)
		var dist := position.distance_to(dest)
		if dist <= step:
			position = dest
			step -= dist
			path.remove_at(0)
		else:
			position += (dest - position) / dist * step
			step = 0.0


func _snap_to_cell(delta: float) -> void:
	var cell := reserved_cell if reserved_cell != NO_CELL else get_cell()
	position = position.move_toward(map.cell_to_world(cell), GameConfig.move_speed_px(data.move_speed) * delta)


# --- Rendu ------------------------------------------------------------------

## Décalage du sprite : petits bonds en marchant, élan vers la cible en attaquant.
func _anim_offset() -> Vector2:
	var off := Vector2(0, -absf(sin(_anim_time * 14.0)) * 2.5)
	if _lunge_t > 0.0:
		var k := 1.0 - _lunge_t / LUNGE_DURATION
		off += _lunge_dir * LUNGE_DISTANCE * sin(k * PI)
	return off


func _draw() -> void:
	var team_color: Color = GameConfig.TEAM_COLORS[team]
	var half := GameConfig.TILE_SIZE * 0.5
	# Socle aux couleurs de l'équipe (blanc si l'escouade est sélectionnée).
	draw_set_transform(Vector2(0, 9), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 11.0, Color(team_color, 0.85))
	if squad.selected:
		draw_arc(Vector2.ZERO, 13.0, 0, TAU, 24, Color.WHITE, 2.5)
	draw_set_transform(Vector2.ZERO)
	var tint := Color.WHITE
	if _flash > 0.0:
		tint = _flash_color * 1.6
	elif is_burning():
		tint = Color(1.0, 0.65, 0.45)
	elif not squad.is_fed():
		tint = Color(0.5, 0.5, 0.5)
	if data.sprite:
		var size := data.sprite.get_size()
		draw_set_transform(_anim_offset(), 0.0, Vector2(_facing, 1))
		draw_texture(data.sprite, -size * 0.5, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(_anim_offset(), 7.0, data.color)
	# Escouade nourrie en priorité (bouton « Nourrir ») : petite pastille verte.
	if squad.ration_priority and squad.members.size() > 0 and squad.members[0] == self:
		draw_circle(Vector2(half - 5, -half + 2), 3.5, Color(0.4, 0.95, 0.4))
	# Barre de PV individuelle.
	var bar := Rect2(Vector2(-half + 6, -half - 1), Vector2(GameConfig.TILE_SIZE - 12, 3))
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(hp) / data.hp, bar.size.y)),
			team_color.lerp(Color.WHITE, 0.15))
