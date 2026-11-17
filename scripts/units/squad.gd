class_name Squad
extends Node2D
## Escouade : entité contrôlable unique composée de plusieurs individus (GDD §5).
## Les statistiques proviennent d'un UnitData ; ce script ne contient aucune valeur
## de gameplay propre à une unité.

signal members_changed(squad: Squad)
signal destroyed(squad: Squad)

enum State { IDLE, MOVING, ATTACKING }

const GROUP := &"squads"
const MEMBER_RADIUS := 5.0

var data: UnitData
var team: int = 0
var map: GameMap
## PV restants de chaque individu vivant.
var member_hp: Array[int] = []

var state: State = State.IDLE
var path: Array[Vector2i] = []
var target: Squad = null
## Cible acquise automatiquement (pas de poursuite hors de portée).
var _auto_target := false
var _attack_cooldown := 0.0
var _repath_timer := 0.0
var _flash := 0.0

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


# --- Ordres -----------------------------------------------------------------

func order_move(cell: Vector2i) -> void:
	target = null
	_auto_target = false
	path = map.find_path(get_cell(), cell)
	state = State.MOVING if not path.is_empty() else State.IDLE


func order_attack(enemy: Squad) -> void:
	if enemy == null or enemy == self or enemy.team == team:
		return
	target = enemy
	_auto_target = false
	path.clear()
	_repath_timer = 0.0
	state = State.ATTACKING


func order_stop() -> void:
	target = null
	path.clear()
	state = State.IDLE


# --- Dégâts -----------------------------------------------------------------

## Reçoit `count` coups de `damage` PV, chacun sur un individu (GDD §5.1).
func take_hits(count: int, damage: int) -> void:
	if not is_alive():
		return
	for i in count:
		if member_hp.is_empty():
			break
		member_hp[0] -= damage
		if member_hp[0] <= 0:
			member_hp.remove_at(0)
	_flash = 0.15
	members_changed.emit(self)
	queue_redraw()
	if member_hp.is_empty():
		destroyed.emit(self)
		queue_free()


# --- Simulation -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)


## Avance la simulation de `delta` secondes (appelable directement par les tests).
func tick(delta: float) -> void:
	if not is_alive():
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()
	match state:
		State.IDLE:
			_auto_acquire()
		State.MOVING:
			_follow_path(delta)
			if path.is_empty():
				state = State.IDLE
		State.ATTACKING:
			_process_attack(delta)


func _process_attack(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		order_stop()
		return
	if CombatSystem.in_range(self, target):
		path.clear()
		_snap_to_cell(delta)
		if _attack_cooldown <= 0.0:
			CombatSystem.perform_attack(self, target, get_tree().get_nodes_in_group(GROUP))
			_attack_cooldown = GameConfig.seconds_per_attack()
		return
	if _auto_target:
		order_stop()
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0 or path.is_empty():
		path = map.find_path(get_cell(), target.get_cell())
		_repath_timer = GameConfig.REPATH_INTERVAL
	_follow_path(delta)


## Escouade inactive : attaque l'ennemi à portée le plus proche, sans le poursuivre.
func _auto_acquire() -> void:
	if not is_inside_tree():
		return
	var best: Squad = null
	var best_d := 1 << 30
	for s in get_tree().get_nodes_in_group(GROUP):
		if s == self or not (s is Squad) or s.team == team or not s.is_alive():
			continue
		var d := CombatSystem.grid_distance(get_cell(), s.get_cell())
		if d <= data.attack_range and d < best_d:
			best = s
			best_d = d
	if best:
		order_attack(best)
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


## Recentre l'escouade sur sa case quand elle s'arrête pour combattre.
func _snap_to_cell(delta: float) -> void:
	var dest := map.cell_to_world(get_cell())
	position = position.move_toward(dest, GameConfig.move_speed_px(data.move_speed) * delta)


# --- Rendu ------------------------------------------------------------------

func _member_offsets(n: int) -> Array[Vector2]:
	var o := GameConfig.TILE_SIZE * 0.2
	match n:
		1: return [Vector2.ZERO]
		2: return [Vector2(-o, 0), Vector2(o, 0)]
		3: return [Vector2(-o, -o), Vector2(o, -o), Vector2(0, o)]
		_: return [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)]


func _draw() -> void:
	if data == null:
		return
	var team_color: Color = GameConfig.TEAM_COLORS[team]
	var half := GameConfig.TILE_SIZE * 0.5
	if selected:
		draw_arc(Vector2.ZERO, half * 0.95, 0, TAU, 32, Color.WHITE, 2.0)
	var font := ThemeDB.fallback_font
	var offsets := _member_offsets(alive_count())
	for i in mini(offsets.size(), alive_count()):
		var p: Vector2 = offsets[i]
		draw_circle(p, MEMBER_RADIUS + 1.5, team_color)
		draw_circle(p, MEMBER_RADIUS, Color.WHITE if _flash > 0.0 else data.color)
	draw_string(font, Vector2(-half, half + 1), data.short_label, HORIZONTAL_ALIGNMENT_CENTER,
			GameConfig.TILE_SIZE, 10, Color(1, 1, 1, 0.9))
	# Barre de PV totale de l'escouade.
	var ratio := float(total_hp()) / float(data.max_total_hp())
	var bar := Rect2(Vector2(-half + 3, -half - 2), Vector2(GameConfig.TILE_SIZE - 6, 3))
	draw_rect(bar, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), team_color.lerp(Color.WHITE, 0.2))
