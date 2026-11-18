class_name Building
extends MapObject
## Bâtiment d'un joueur. Construit par des ouvriers adjacents : chaque ouvrier
## apporte une unité de travail par seconde ; il faut `build_turns` tours de
## travail (plus il y a d'ouvriers, plus c'est rapide). Une fois terminé, il
## stocke / produit / consomme selon ses données (géré par EconomySystem).

signal completed(building: Building)
## Fin d'un recrutement (Caserne) : la scène fait apparaître l'escouade.
signal recruited(building: Building, unit: UnitData)

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


func setup(p_data: BuildingData, p_team: int, p_map: GameMap, p_cell: Vector2i) -> Building:
	data = p_data
	team = p_team
	hp = data.hp
	name = "%s_%d_%d" % [data.id, p_cell.x, p_cell.y]
	place_on(p_map, p_cell)
	if work_needed() <= 0.0:
		_complete()
	return self


func work_needed() -> float:
	return data.build_turns * GameConfig.SECONDS_PER_TURN


func can_be_worked_by(squad: Squad) -> bool:
	return not is_complete and squad.data.is_worker and squad.team == team


func work(_worker: Individual, delta: float) -> bool:
	if is_complete:
		return false
	progress += delta
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
	if not is_complete:
		tint = Color(1, 1, 1, 0.45)
	elif not fed:
		tint = Color(0.55, 0.55, 0.55)
	_draw_sprite(data.sprite, tint)
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
