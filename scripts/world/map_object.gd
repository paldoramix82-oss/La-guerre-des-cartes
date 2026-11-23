class_name MapObject
extends Node2D
## Objet fixe sur une case de la carte (bâtiment, gisement) : infranchissable,
## et éventuellement « travaillable » par des ouvriers adjacents.

const GROUP := &"map_objects"

var map: GameMap
var cell := Vector2i.ZERO
## Propriétaire : 0, 1, ou -1 (neutre).
var team: int = -1
## Cases occupées en plus de `cell` (bâtiments de plusieurs cases : Barricade).
var extra_cells: Array[Vector2i] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func _exit_tree() -> void:
	if map:
		for c in occupied_cells():
			map.remove_object(c, self)


func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = [cell]
	out.append_array(extra_cells)
	return out


## Occupe aussi les cases `cells` (en plus de `cell`).
func occupy_extra(cells: Array) -> void:
	for c in cells:
		extra_cells.append(c)
		map.add_object(c, self)


## Distance (en cases) entre `c` et la case occupée la plus proche.
func distance_from(c: Vector2i) -> int:
	var best := 1 << 30
	for oc in occupied_cells():
		best = mini(best, CombatSystem.grid_distance(c, oc))
	return best


func place_on(p_map: GameMap, p_cell: Vector2i) -> void:
	map = p_map
	cell = p_cell
	position = map.cell_to_world(cell)
	map.add_object(cell, self)


func is_alive() -> bool:
	return true


## L'escouade `squad` peut-elle travailler sur cet objet ?
func can_be_worked_by(_squad: Squad) -> bool:
	return false


## Un ouvrier adjacent travaille `delta` secondes. Retourne false s'il n'y a plus rien à faire.
func work(_worker: Individual, _delta: float) -> bool:
	return false


## Nombre d'individus qui travaillent cet objet en ce moment (adjacents, arrêtés,
## nourris). `filter(squad)` restreint (ex. mineurs).
func crew(filter: Callable = Callable()) -> int:
	return maxi(crew_count(filter), 1)


## Comme `crew`, mais peut valoir 0.
func crew_count(filter: Callable = Callable()) -> int:
	if not is_inside_tree():
		return 0
	var n := 0
	for s in get_tree().get_nodes_in_group(Squad.GROUP):
		if s.work_target != self or s.sheltered or not s.is_fed():
			continue
		if filter.is_valid() and not filter.call(s):
			continue
		for m in s.members:
			if is_instance_valid(m) and not m.is_moving() and CombatSystem.grid_distance(m.get_cell(), cell) == 1:
				n += 1
	return n


## Travail d'une équipe (décision de l'auteur) : chaque ouvrier en plus divise le
## temps par 2 (1 ouvrier : temps normal, 2 : moitié, 3 : quart...).
## Retourne la part d'avancement apportée par UN ouvrier pendant `delta`.
func crew_share(delta: float, n: int) -> float:
	return delta * pow(2.0, n - 1) / n


func remove() -> void:
	if map:
		for c in occupied_cells():
			map.remove_object(c, self)
	queue_free()


func _draw_sprite(tex: Texture2D, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return
	# Sprites 16 px agrandis x2 pour occuper la case ; plus grands : taille réelle.
	var size := tex.get_size() * (2.0 if tex.get_size().x <= 16 else 1.0)
	var bottom := Vector2(0, GameConfig.TILE_SIZE * 0.5)
	draw_texture_rect(tex, Rect2(bottom - Vector2(size.x * 0.5, size.y), size), false, tint)
