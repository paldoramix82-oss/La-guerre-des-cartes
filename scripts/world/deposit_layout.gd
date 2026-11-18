class_name DepositLayout
extends RefCounted
## Emplacements des gisements [PROVISOIRE] (GDD §13 : carte à définir).
## Positions pour le joueur 1 / la moitié gauche de la jungle ; reproduites par
## symétrie (rotation de 180°) pour que les deux joueurs aient la même carte.

const LAYOUT := [
	# Royaume
	[&"forest", Vector2i(11, 6)], [&"forest", Vector2i(12, 7)],
	[&"berries", Vector2i(11, 12)],
	[&"metal_vein", Vector2i(12, 24)],
	[&"gold_vein", Vector2i(11, 29)],
	# Jungle
	[&"forest", Vector2i(17, 9)], [&"forest", Vector2i(20, 15)], [&"forest", Vector2i(16, 22)],
	[&"berries", Vector2i(18, 31)],
	[&"metal_vein", Vector2i(22, 5)], [&"metal_vein", Vector2i(23, 27)],
	[&"gold_vein", Vector2i(25, 13)],
]


static func spawn_all(map: GameMap, economy: EconomySystem, parent: Node) -> Array[Deposit]:
	var out: Array[Deposit] = []
	for entry in LAYOUT:
		var cell: Vector2i = entry[1]
		for c in [cell, Vector2i(map.width - 1 - cell.x, map.height - 1 - cell.y)]:
			if not map.is_free(c):
				continue
			var d := Deposit.new()
			parent.add_child(d)
			d.setup(DepositDatabase.get_deposit(entry[0]), map, c, economy)
			out.append(d)
	return out
