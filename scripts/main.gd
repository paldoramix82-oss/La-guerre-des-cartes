extends Node2D
## Point d'entrée : assemble carte, économie, gisements, escouades, contrôles et HUD.

## Composition de test [PROVISOIRE] : une escouade de chaque type par joueur.
const TEST_ARMY: Array[StringName] = [&"warrior", &"warrior", &"archer", &"cavalier", &"mage", &"healer", &"miner"]

@onready var map: GameMap = $GameMap
@onready var squads_root: Node2D = $Squads
@onready var selection: SelectionController = $SelectionController
@onready var camera: CameraController = $Camera
@onready var hud: Hud = $HUD
var economy: EconomySystem


func _ready() -> void:
	economy = EconomySystem.new()
	economy.name = "Economy"
	economy.map = map
	add_child(economy)
	economy.workers_requested.connect(_on_workers_requested)
	DepositLayout.spawn_all(map, economy, map)
	hud.economy_system = economy
	hud.build_requested.connect(selection.start_build)
	selection.economy_system = economy
	selection.build_mode_changed.connect(hud.on_build_mode_changed)
	selection.notify.connect(hud.show_notice)
	selection.map = map
	selection.selection_changed.connect(hud.on_selection_changed)
	selection.controlled_team_changed.connect(hud.on_team_changed)
	hud.command.connect(_on_hud_command)
	camera.bounds = Rect2(Vector2.ZERO, map.world_size())
	_spawn_test_armies()
	camera.position = map.cell_to_world(Vector2i(GameConfig.KINGDOM_DEPTH - 4, map.height / 2))
	camera.set_zoom_level(2.0)
	add_child(MusicPlayer.create(GameConfig.MUSIC_BATTLE))


func _spawn_test_armies() -> void:
	for team in 2:
		var x := 6 if team == 0 else map.width - 7
		# Une escouade toutes les 3 lignes : ses individus se placent autour (une case chacun).
		var start_y := map.height / 2 - (TEST_ARMY.size() * 3) / 2 + 1
		for i in TEST_ARMY.size():
			var unit := UnitDatabase.get_unit(TEST_ARMY[i])
			if unit == null:
				push_error("Unité inconnue : %s" % TEST_ARMY[i])
				continue
			spawn_squad(unit, team, map.nearest_walkable(Vector2i(x, start_y + i * 3)))


func spawn_squad(unit: UnitData, team: int, cell: Vector2i) -> Squad:
	var squad := Squad.new()
	squads_root.add_child(squad)
	squad.setup(unit, team, map, cell)
	return squad


## Une Cabane Ouvrier terminée fait apparaître ses ouvriers à côté d'elle.
func _on_workers_requested(hut: Building, count: int) -> void:
	var unit := UnitDatabase.get_unit(&"worker")
	for i in count:
		var cells := map.spread_cells(hut.cell, 1)
		if cells.is_empty():
			return
		var w := spawn_squad(unit, hut.team, cells[0])
		w.home = hut


## Commandes des boutons du HUD.
func _on_hud_command(cmd: StringName) -> void:
	match cmd:
		&"select_all": selection.select_all()
		&"deselect": selection.set_selection([])
		&"stop": selection.stop_selected()
		&"zoom_in": camera.zoom_in()
		&"zoom_out": camera.zoom_out()
		&"switch_team": selection.toggle_team()
