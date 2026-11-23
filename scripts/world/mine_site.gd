class_name MineSite
extends MapObject
## Mine (puits) — décisions de l'auteur :
## - sans PV, indestructible ; neutre au départ ;
## - **capture** : éliminer toutes les unités présentes, puis rester un moment
##   (GameConfig.MINE_CAPTURE_SECONDS) sans ennemi dans la zone (MINE_CAPTURE_RADIUS) ;
##   l'adversaire la reprend de la même façon ; des unités laissées sur place la gardent ;
## - **exploitation** : après capture, payer le coût de la Mine (data/buildings/mine.tres)
##   puis la faire construire par des ouvriers (2 tours) — une seule fois : une mine
##   reprise s'exploite sans reconstruire ;
## - **production** : 5 métal + 1 lingot (10 Gd) à chaque cycle ; cycle de 20 s (1 tour)
##   sans mineur, 15 / 12 / 10 s avec 1 / 2 / 3 mineurs (3 au plus par mine) ;
##   inépuisable ; consommation 3 Nourri / tour (payée par EconomySystem).

signal captured(mine: MineSite, team: int)

const SPRITE := "res://assets/sprites/props/well.png"
const CENTRAL_SPRITE := "res://assets/sprites/props/well_magic.png"
const DATA_ID := &"mine"
## Durée d'un cycle de production (s) selon le nombre de mineurs (0 à 3) — valeurs de l'auteur.
const MINER_CYCLE := [20.0, 15.0, 12.0, 10.0]
const MAX_MINERS := 3

var is_central := false
var data: BuildingData
## Joueur qui capture en ce moment, et avancement (s).
var capturing_team := -1
var capture_progress := 0.0
## Exploitation : chantier lancé, avancement (secondes-ouvrier), terminée.
var exploit_started := false
var exploit_progress := 0.0
var exploited := false
## Entretien payé ce tour-ci.
var fed := true
var _production_timer := 0.0
var selected := false:
	set(value):
		selected = value
		queue_redraw()


func setup(p_map: GameMap, p_cell: Vector2i, central: bool) -> MineSite:
	is_central = central
	data = BuildingDatabase.get_building(DATA_ID)
	name = "mine_%d_%d" % [p_cell.x, p_cell.y]
	place_on(p_map, p_cell)
	return self


func _physics_process(delta: float) -> void:
	tick(delta)


# --- Capture ---------------------------------------------------------------------------

## Camps présents (individus vivants, hors ouvriers cachés) dans la zone de capture.
func teams_present() -> Array:
	var teams := []
	if not is_inside_tree():
		return teams
	for n in get_tree().get_nodes_in_group(Individual.GROUP):
		var m := n as Individual
		if m == null or not m.is_alive() or m.squad.sheltered:
			continue
		if CombatSystem.grid_distance(m.get_cell(), cell) <= GameConfig.MINE_CAPTURE_RADIUS and not (m.team in teams):
			teams.append(m.team)
	return teams


func tick(delta: float) -> void:
	_tick_production(delta)
	var teams := teams_present()
	# Capture possible : un seul camp présent, qui est un joueur et pas déjà propriétaire.
	if teams.size() == 1 and teams[0] != GameConfig.MONSTER_TEAM and teams[0] != team:
		if capturing_team != teams[0]:
			capturing_team = teams[0]
			capture_progress = 0.0
		capture_progress += delta
		if capture_progress >= GameConfig.MINE_CAPTURE_SECONDS:
			team = capturing_team
			capturing_team = -1
			capture_progress = 0.0
			captured.emit(self, team)
		queue_redraw()
	elif capture_progress > 0.0 and not (teams.size() > 1 and capturing_team in teams):
		# Zone quittée : la capture repart de zéro (contestée : elle est seulement suspendue).
		capture_progress = 0.0
		capturing_team = -1
		queue_redraw()


## Production : à chaque cycle, 5 métal + 1 lingot pour le propriétaire (si nourrie).
func _tick_production(delta: float) -> void:
	if not is_producing() or not fed or not is_inside_tree():
		return
	_production_timer += delta
	var cycle := production_cycle()
	if _production_timer >= cycle:
		_production_timer -= cycle
		var eco := get_tree().get_first_node_in_group(EconomySystem.GROUP) as EconomySystem
		if eco:
			eco.economy(team).add_all(data.production)


# --- Exploitation ----------------------------------------------------------------------

func needs_exploitation() -> bool:
	return team >= 0 and team <= 1 and not exploited and not exploit_started


func can_be_worked_by(squad: Squad) -> bool:
	if squad.team != team:
		return false
	if exploit_started and not exploited:
		return squad.data.is_worker
	if exploited and squad.data.can_mine:
		return squad.work_target == self or assigned_miners() + squad.alive_count() <= MAX_MINERS
	return false


## Mineurs envoyés dans cette mine (en route ou au travail).
func assigned_miners() -> int:
	var n := 0
	if is_inside_tree():
		for s in get_tree().get_nodes_in_group(Squad.GROUP):
			if s.work_target == self and s.data.can_mine:
				n += s.alive_count()
	return n


## Mineurs au travail (à côté de la mine).
func active_miners() -> int:
	return mini(crew_count(func(s): return s.data.can_mine), MAX_MINERS)


func production_cycle() -> float:
	return MINER_CYCLE[active_miners()]


func work_needed() -> float:
	return data.build_turns * GameConfig.SECONDS_PER_TURN


func work(_worker: Individual, delta: float) -> bool:
	if not can_be_worked_by(_worker.squad):
		return false
	if exploited:
		return true  # mineur : sa présence accélère la production (voir tick)
	exploit_progress += crew_share(delta, crew(func(s): return s.data.is_worker))
	queue_redraw()
	if exploit_progress >= work_needed():
		exploited = true
		return false
	return true


func is_producing() -> bool:
	return exploited and team >= 0 and team <= 1


# --- Rendu -----------------------------------------------------------------------------

func _draw() -> void:
	_draw_sprite(load(CENTRAL_SPRITE if is_central else SPRITE), Color.WHITE if fed or not is_producing() else Color(0.55, 0.55, 0.55))
	var half := GameConfig.TILE_SIZE * 0.5
	var ring: Color = Color(1, 0.85, 0.3, 0.7) if team < 0 else GameConfig.TEAM_COLORS[team]
	draw_arc(Vector2(0, half * 0.6), half * 0.9, 0, TAU, 24, ring, 2.0 if team >= 0 else 1.5)
	if selected:
		draw_rect(Rect2(Vector2(-half, -half), Vector2(GameConfig.TILE_SIZE, GameConfig.TILE_SIZE)), Color.WHITE, false, 2.0)
	if capture_progress > 0.0 and capturing_team >= 0:
		var k := capture_progress / GameConfig.MINE_CAPTURE_SECONDS
		draw_arc(Vector2.ZERO, half * 1.1, -PI / 2, -PI / 2 + TAU * k, 32, GameConfig.TEAM_COLORS[capturing_team], 3.0)
	if exploit_started and not exploited:
		var bar := Rect2(Vector2(-half + 4, -half - 2), Vector2(GameConfig.TILE_SIZE - 8, 4))
		draw_rect(bar.grow(1), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * exploit_progress / work_needed(), bar.size.y)), Color(1, 0.85, 0.3))
