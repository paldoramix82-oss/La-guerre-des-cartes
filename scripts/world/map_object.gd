class_name MapObject
extends Node2D
## Objet fixe sur une case de la carte (bâtiment, gisement) : infranchissable,
## et éventuellement « travaillable » par des ouvriers adjacents.

const GROUP := &"map_objects"

var map: GameMap
var cell := Vector2i.ZERO
## Propriétaire : 0, 1, ou -1 (neutre).
var team: int = -1


func _enter_tree() -> void:
	add_to_group(GROUP)


func _exit_tree() -> void:
	if map:
		map.remove_object(cell, self)


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


func remove() -> void:
	if map:
		map.remove_object(cell, self)
	queue_free()


func _draw_sprite(tex: Texture2D, tint: Color = Color.WHITE) -> void:
	if tex == null:
		return
	# Sprites 16 px agrandis x2 pour occuper la case ; plus grands : taille réelle.
	var size := tex.get_size() * (2.0 if tex.get_size().x <= 16 else 1.0)
	var bottom := Vector2(0, GameConfig.TILE_SIZE * 0.5)
	draw_texture_rect(tex, Rect2(bottom - Vector2(size.x * 0.5, size.y), size), false, tint)
