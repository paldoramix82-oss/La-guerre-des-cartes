class_name Squad
extends Node2D
## Escouade : entité contrôlable unique composée de plusieurs individus (GDD §5).
## Les statistiques proviennent d'un UnitData ; ce script ne contient aucune valeur
## de gameplay propre à une unité.

signal members_changed(squad: Squad)
signal destroyed(squad: Squad)

## ACTING = attaque (ennemi) ou soin (allié) selon `data.action`.
enum State { IDLE, MOVING, ACTING }

const GROUP := &"squads"

var data: UnitData
var team: int = 0
var map: GameMap
## PV restants de chaque individu vivant.
var member_hp: Array[int] = []

var state: State = State.IDLE
var path: Array[Vector2i] = []
var target: Squad = null
## Brûlures actives, par type d'unité source : {hits, damage, turns_left, timer}.
var burns: Dictionary = {}
## Cible acquise automatiquement (pas de poursuite hors de portée).
var _auto_target := false
var _action_cooldown := 0.0
var _repath_timer := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE

var selected := false:
	set(value):
		selected = value
		queue_redraw()


func setup(p_data: UnitData, p_team: int, p_map: GameMap, cell: Vector2i) -> Squad:
	data = p_data
	team = p_team
	map = p_map
	member_hp.clear()
	for i in data.squad_size:
		member_hp.append(data.hp)
	position = map.cell_to_world(cell)
	name = "%s_%d" % [data.id, get_instance_id()]
	return self


func _enter_tree() -> void:
	add_to_group(GROUP)


# --- État -------------------------------------------------------------------

func get_cell() -> Vector2i:
	return map.world_to_cell(position)


func alive_count() -> int:
	return member_hp.size()


func is_alive() -> bool:
	return not member_hp.is_empty()


func total_hp() -> int:
	var t := 0
	for hp in member_hp:
		t += hp
	return t


## Au moins un individu vivant n'a pas tous ses PV.
func is_wounded() -> bool:
	for hp in member_hp:
		if hp < data.hp:
			return true
	return false


func is_burning() -> bool:
	return not burns.is_empty()


# --- Ordres -----------------------------------------------------------------

func order_move(cell: Vector2i) -> void:
	target = null
	_auto_target = false
	path = map.find_path(get_cell(), cell)
	state = State.MOVING if not path.is_empty() else State.IDLE


## Attaque (ennemi) ou soigne (allié) `other` selon l'action de l'unité.
## Retourne false si cette escouade ne peut pas agir sur `other`.
func order_target(other: Squad) -> bool:
	if not CombatSystem.can_target(self, other):
		return false
	target = other
	_auto_target = false
	path.clear()
	_repath_timer = 0.0
	state = State.ACTING
	return true


func order_stop() -> void:
	target = null
	path.clear()
	state = State.IDLE


# --- Dégâts et soins ---------------------------------------------------------

## Reçoit `count` coups de `damage` PV, chacun sur un individu (GDD §5.1).
func take_hits(count: int, damage: int) -> void:
	if not is_alive() or damage <= 0:
		return
	for i in count:
		if member_hp.is_empty():
			break
		member_hp[0] -= damage
		if member_hp[0] <= 0:
			member_hp.remove_at(0)
	_flash_hit(Color.WHITE)
	members_changed.emit(self)
	if member_hp.is_empty():
		destroyed.emit(self)
		queue_free()


## Reçoit `count` soins de `amount` PV, chacun sur l'individu le plus blessé.
func heal(count: int, amount: int) -> void:
	if not is_alive() or amount <= 0:
		return
	for i in count:
		var idx := _most_wounded_index()
		if idx < 0:
			break
		member_hp[idx] = mini(data.hp, member_hp[idx] + amount)
	_flash_hit(Color(0.5, 1, 0.5))
	members_changed.emit(self)


## Applique (ou renouvelle) une brûlure : `hits` coups de `damage` par tour pendant `turns` tours.
func apply_burn(source: StringName, hits: int, damage: int, turns: int) -> void:
	burns[source] = {"hits": hits, "damage": damage, "turns_left": turns, "timer": GameConfig.SECONDS_PER_TURN}


func _most_wounded_index() -> int:
	var best := -1
	for i in member_hp.size():
		if member_hp[i] < data.hp and (best < 0 or member_hp[i] < member_hp[best]):
			best = i
	return best


func _flash_hit(color: Color) -> void:
	_flash = 0.15
	_flash_color = color
	queue_redraw()


# --- Simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)


## Avance la simulation de `delta` secondes (appelable directement par les tests).
func tick(delta: float) -> void:
	if not is_alive():
		return
	_action_cooldown = maxf(0.0, _action_cooldown - delta)
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	_process_burns(delta)
	if not is_alive():
		return
	match state:
		State.IDLE:
			_auto_acquire()
		State.MOVING:
			_follow_path(delta)
			if path.is_empty():
				state = State.IDLE
		State.ACTING:
			_process_action(delta)


func _process_burns(delta: float) -> void:
	for source in burns.keys():
		var b: Dictionary = burns[source]
		b.timer -= delta
		if b.timer > 0.0:
			continue
		b.timer += GameConfig.SECONDS_PER_TURN
		b.turns_left -= 1
		if b.turns_left <= 0:
			burns.erase(source)
		take_hits(b.hits, b.damage)
		if not is_alive():
			return
	queue_redraw()


func _process_action(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		order_stop()
		return
	var healing := data.action == UnitData.ActionType.HEAL
	if healing and not target.is_wounded():
		order_stop()
		return
	if CombatSystem.in_range(self, target):
		path.clear()
		_snap_to_cell(delta)
		if _action_cooldown <= 0.0:
			var squads := get_tree().get_nodes_in_group(GROUP)
			if healing:
				CombatSystem.perform_heal(self, target, squads)
			else:
				CombatSystem.perform_attack(self, target, squads)
			_action_cooldown = GameConfig.seconds_per_attack()
		return
	if _auto_target:
		order_stop()
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0 or path.is_empty():
		path = map.find_path(get_cell(), target.get_cell())
		_repath_timer = GameConfig.REPATH_INTERVAL
	_follow_path(delta)


## Escouade inactive : agit sur la cible valide la plus proche à portée
## (ennemi pour l'attaque, allié blessé pour le soin), sans la poursuivre.
func _auto_acquire() -> void:
	if not is_inside_tree():
		return
	var healing := data.action == UnitData.ActionType.HEAL
	var best: Squad = null
	var best_d := 1 << 30
	for s in get_tree().get_nodes_in_group(GROUP):
		if not (s is Squad) or not CombatSystem.can_target(self, s):
			continue
		if healing and not s.is_wounded():
			continue
		var d := CombatSystem.grid_distance(get_cell(), s.get_cell())
		if d <= data.attack_range and d < best_d:
			best = s
			best_d = d
	if best:
		order_target(best)
		_auto_target = true


func _follow_path(delta: float) -> void:
	var step := GameConfig.move_speed_px(data.move_speed) * delta
	while step > 0.0 and not path.is_empty():
		var dest := map.cell_to_world(path[0])
		var dist := position.distance_to(dest)
		if dist <= step:
			position = dest
			step -= dist
			path.remove_at(0)
		else:
			position += (dest - position) / dist * step
			step = 0.0


## Recentre l'escouade sur sa case quand elle s'arrête pour agir.
func _snap_to_cell(delta: float) -> void:
	var dest := map.cell_to_world(get_cell())
	position = position.move_toward(dest, GameConfig.move_speed_px(data.move_speed) * delta)


# --- Rendu ------------------------------------------------------------------

func _member_offsets(n: int) -> Array[Vector2]:
	var o := GameConfig.TILE_SIZE * 0.2
	match n:
		1: return [Vector2.ZERO]
		2: return [Vector2(-o, 0), Vector2(o, 0)]
		3: return [Vector2(-o, -o * 0.6), Vector2(o, -o * 0.6), Vector2(0, o * 0.6)]
		_: return [Vector2(-o, -o * 0.6), Vector2(o, -o * 0.6), Vector2(-o, o * 0.6), Vector2(o, o * 0.6)]


func _draw() -> void:
	if data == null:
		return
	var team_color: Color = GameConfig.TEAM_COLORS[team]
	var half := GameConfig.TILE_SIZE * 0.5
	if selected:
		draw_set_transform(Vector2(0, half * 0.55), 0.0, Vector2(1, 0.45))
		draw_arc(Vector2.ZERO, half * 0.95, 0, TAU, 32, Color.WHITE, 3.0)
		draw_set_transform(Vector2.ZERO)
	var modulate_color := Color.WHITE
	if _flash > 0.0:
		modulate_color = _flash_color * 1.6
	elif is_burning():
		modulate_color = Color(1.0, 0.65, 0.45)
	var offsets := _member_offsets(alive_count())
	for i in mini(offsets.size(), alive_count()):
		_draw_member(offsets[i], team_color, modulate_color)
	# Barre de PV totale de l'escouade.
	var ratio := float(total_hp()) / float(data.max_total_hp())
	var bar := Rect2(Vector2(-half + 4, -half - 6), Vector2(GameConfig.TILE_SIZE - 8, 4))
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), team_color.lerp(Color.WHITE, 0.15))


func _draw_member(p: Vector2, team_color: Color, tint: Color) -> void:
	# Socle aux couleurs de l'équipe sous les pieds.
	draw_set_transform(p + Vector2(0, 9), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 8.0, Color(team_color, 0.85))
	draw_set_transform(Vector2.ZERO)
	if data.sprite == null:
		draw_circle(p, 6.0, data.color)
		return
	var size := data.sprite.get_size()
	# L'équipe 2 regarde vers la gauche.
	var flip := -1.0 if team == 1 else 1.0
	draw_set_transform(p, 0.0, Vector2(flip, 1))
	draw_texture(data.sprite, -size * 0.5, tint)
	draw_set_transform(Vector2.ZERO)
