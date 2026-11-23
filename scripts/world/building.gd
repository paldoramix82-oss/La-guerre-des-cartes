class_name Building
extends MapObject
## Bâtiment d'un joueur. Construit par des ouvriers adjacents : il faut `build_turns`
## tours de travail pour un ouvrier ; chaque ouvrier en plus divise le temps par 2. Une fois terminé, il
## stocke / produit / consomme selon ses données (géré par EconomySystem).

signal completed(building: Building)
## Fin d'un recrutement (Caserne) : la scène fait apparaître l'escouade.
signal recruited(building: Building, unit: UnitData)
## Détruit (PV à 0) : il disparaît de la carte.
signal destroyed(building: Building)

var data: BuildingData
## Travail accompli (secondes-ouvrier).
var progress := 0.0
var is_complete := false
## Entretien payé ce tour-ci : sinon le bâtiment (et ses ouvriers) ne fonctionne pas.
var fed := true
var hp := 0
## File de recrutement (Caserne) : une escouade à la fois (GDD §5.3).
var queue: Array[UnitData] = []
## Avancement du recrutement en cours, en secondes.
var recruit_progress := 0.0
var selected := false:
	set(value):
		selected = value
		queue_redraw()
## Tourelle (défenses : Tour Archer, Canon, Cabane Garde, Mortier), ou null.
var turret: DefenseTurret = null
## Abri (Cabane Garde) : unités placées à l'intérieur, ou null.
var garrison: Garrison = null
var _flash := 0.0


## Forme choisie à la pose (bâtiments orientables : Barricade).
var rotation_index := 0


func setup(p_data: BuildingData, p_team: int, p_map: GameMap, p_cell: Vector2i, p_rotation: int = 0) -> Building:
	rotation_index = p_rotation
	data = p_data
	team = p_team
	hp = data.hp
	name = "%s_%d_%d" % [data.id, p_cell.x, p_cell.y]
	place_on(p_map, p_cell)
	occupy_extra(data.footprint_cells(p_cell, rotation_index).slice(1))
	if data.garrison_capacity > 0:
		garrison = Garrison.new(self)
	elif data.damage > 0 and data.attack_range > 0 and data.category == BuildingData.Category.DEFENSE:
		turret = DefenseTurret.new(self)
	if work_needed() <= 0.0:
		_complete()
	return self


func _physics_process(delta: float) -> void:
	tick(delta)


## Avance la défense / l'abri / l'effet de touche (appelable par les tests).
func tick(delta: float) -> void:
	if turret and is_complete and fed:
		turret.tick(delta)
	if garrison and is_complete:
		garrison.tick(delta)
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()


# --- Dégâts ---------------------------------------------------------------------------

## Peut être attaqué et détruit (bâtiments sans PV : indestructibles — décision de l'auteur).
func is_attackable() -> bool:
	return data.destructible and data.hp > 0 and hp > 0


func is_alive() -> bool:
	return hp > 0 or not is_attackable_kind()


func is_attackable_kind() -> bool:
	return data.destructible and data.hp > 0


func take_damage(amount: int, attacker_team: int = -1) -> void:
	if not is_attackable() or amount <= 0:
		return
	hp -= amount
	_flash = 0.15
	Effects.floating_text(self, position, "-%d" % amount, Color(1, 0.4, 0.35))
	queue_redraw()
	if hp <= 0:
		hp = 0
		Effects.burst(self, [position], Color(0.9, 0.6, 0.3))
		if garrison:
			garrison.release_all()
		destroyed.emit(self)
		remove()


func work_needed() -> float:
	return data.build_turns * GameConfig.SECONDS_PER_TURN


func can_be_worked_by(squad: Squad) -> bool:
	return not is_complete and squad.data.is_worker and squad.team == team


func work(_worker: Individual, delta: float) -> bool:
	if is_complete:
		return false
	progress += crew_share(delta, crew())
	queue_redraw()
	if progress >= work_needed():
		_complete()
		return false
	return true


## Peut recruter (Caserne terminée).
func can_recruit(unit: UnitData) -> bool:
	return is_complete and data.recruit_per_turn.has(unit.id)


## Durée de recrutement d'une escouade de `unit`, en secondes :
## effectif / cadence (individus par tour) de la Caserne.
func recruit_time(unit: UnitData) -> float:
	var rate: int = data.recruit_per_turn.get(unit.id, 0)
	if rate <= 0:
		return INF
	return float(unit.squad_size) / rate * GameConfig.SECONDS_PER_TURN


## Avance la file de recrutement.
func tick_recruitment(delta: float) -> void:
	if queue.is_empty() or not is_complete or not fed:
		return
	recruit_progress += delta
	if recruit_progress >= recruit_time(queue[0]):
		var unit: UnitData = queue.pop_front()
		recruit_progress = 0.0
		recruited.emit(self, unit)
	queue_redraw()


## Individus en file de recrutement (capacité : GameConfig.BARRACKS_CAPACITY).
func queued_individuals() -> int:
	var n := 0
	for u in queue:
		n += u.squad_size
	return n


func recruit_ratio() -> float:
	if queue.is_empty():
		return 0.0
	return clampf(recruit_progress / recruit_time(queue[0]), 0.0, 1.0)


func _complete() -> void:
	is_complete = true
	progress = work_needed()
	queue_redraw()
	completed.emit(self)


func set_fed(value: bool) -> void:
	if fed != value:
		fed = value
		queue_redraw()


func _draw() -> void:
	var team_color: Color = GameConfig.TEAM_COLORS[team]
	var half := GameConfig.TILE_SIZE * 0.5
	# Socle aux couleurs du joueur.
	draw_rect(Rect2(Vector2(-half + 2, -half + 2), Vector2(GameConfig.TILE_SIZE - 4, GameConfig.TILE_SIZE - 4)),
			Color(team_color, 0.35))
	if selected:
		draw_rect(Rect2(Vector2(-half, -half), Vector2(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)), Color.WHITE, false, 2.0)
	var tint := Color.WHITE
	if _flash > 0.0:
		tint = Color(1.8, 1.8, 1.8)
	elif not is_complete:
		tint = Color(1, 1, 1, 0.45)
	elif not fed:
		tint = Color(0.55, 0.55, 0.55)
	_draw_sprite(data.sprite, tint)
	for c in extra_cells:
		draw_set_transform(Vector2(c - cell) * GameConfig.TILE_SIZE)
		draw_rect(Rect2(Vector2(-half + 2, -half + 2), Vector2(GameConfig.TILE_SIZE - 4, GameConfig.TILE_SIZE - 4)), Color(team_color, 0.35))
		_draw_sprite(data.sprite, tint)
		draw_set_transform(Vector2.ZERO)
	if not is_complete:
		var bar := Rect2(Vector2(-half + 4, -half - 2), Vector2(GameConfig.TILE_SIZE - 8, 4))
		draw_rect(bar.grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress / work_needed(), bar.size.y)), Color(1, 0.85, 0.3))
	elif not queue.is_empty():
		# Recrutement en cours : barre d'avancement + nombre d'escouades en file.
		var bar := Rect2(Vector2(-half + 4, -half - 2), Vector2(GameConfig.TILE_SIZE - 8, 4))
		draw_rect(bar.grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * recruit_ratio(), bar.size.y)), Color(0.5, 0.85, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(half - 8, -half + 8), str(queue.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	elif not fed:
		draw_string(ThemeDB.fallback_font, Vector2(-half, -half + 4), "!", HORIZONTAL_ALIGNMENT_CENTER,
				GameConfig.TILE_SIZE, 16, Color(1, 0.4, 0.3))
	# Barre de PV (bâtiment endommagé).
	if is_attackable_kind() and hp < data.hp and is_complete:
		var hb := Rect2(Vector2(-half + 4, half - 3), Vector2(GameConfig.TILE_SIZE - 8, 3))
		draw_rect(hb.grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * float(hp) / data.hp, hb.size.y)), team_color.lerp(Color.WHITE, 0.2))
	if turret and selected:
		draw_arc(Vector2.ZERO, (data.attack_range + 0.5) * GameConfig.TILE_SIZE, 0, TAU, 48, Color(team_color, 0.5), 1.5)
