extends Node2D
## Point d'entrée du Prototype 1 : assemble carte, escouades, contrôles et HUD.

## Composition de test [PROVISOIRE] : une escouade de chaque type par joueur.
const TEST_ARMY: Array[StringName] = [&"warrior", &"warrior", &"archer", &"cavalier", &"mage", &"healer", &"miner"]

@onready var map: GameMap = $GameMap
@onready var squads_root: Node2D = $Squads
@onready var selection: SelectionController = $SelectionController
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	selection.map = map
	selection.selection_changed.connect(hud.on_selection_changed)
	selection.controlled_team_changed.connect(hud.on_team_changed)
	camera.bounds = Rect2(Vector2.ZERO, map.world_size())
	_spawn_test_armies()
	camera.position = map.cell_to_world(Vector2i(GameConfig.KINGDOM_DEPTH - 4, map.height / 2))
	camera.zoom = Vector2(1.5, 1.5)
	add_child(MusicPlayer.create(GameConfig.MUSIC_BATTLE))



func _spawn_test_armies() -> void:
	for team in 2:
		var x := 6 if team == 0 else map.width - 7
		var start_y := map.height / 2 - TEST_ARMY.size() / 2
		for i in TEST_ARMY.size():
			var unit := UnitDatabase.get_unit(TEST_ARMY[i])
			if unit == null:
				push_error("Unité inconnue : %s" % TEST_ARMY[i])
				continue
			spawn_squad(unit, team, map.nearest_walkable(Vector2i(x, start_y + i)))


func spawn_squad(unit: UnitData, team: int, cell: Vector2i) -> Squad:
	var squad := Squad.new().setup(unit, team, map, cell)
	squads_root.add_child(squad)
	return squad
