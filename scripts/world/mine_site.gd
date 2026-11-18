class_name MineSite
extends MapObject
## Mine (puits) : sans PV, indestructible ; se capture par siège et se reprend,
## produit un peu d'or et de métal (décisions de l'auteur). Capture et production :
## Prototype 4 (quantités à définir). Pour l'instant : repère neutre sur la carte.

const SPRITE := "res://assets/sprites/props/well.png"
const CENTRAL_SPRITE := "res://assets/sprites/props/well_magic.png"

var is_central := false


func setup(p_map: GameMap, p_cell: Vector2i, central: bool) -> MineSite:
	is_central = central
	name = "mine_%d_%d" % [p_cell.x, p_cell.y]
	place_on(p_map, p_cell)
	return self


func _draw() -> void:
	_draw_sprite(load(CENTRAL_SPRITE if is_central else SPRITE))
	var half := GameConfig.TILE_SIZE * 0.5
	draw_arc(Vector2(0, half * 0.6), half * 0.9, 0, TAU, 24, Color(1, 0.85, 0.3, 0.6), 1.5)
