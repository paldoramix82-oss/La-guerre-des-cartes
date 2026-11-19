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
var fog: FogOfWar
var cards: CardSystem


func _ready() -> void:
	economy = EconomySystem.new()
	economy.name = "Economy"
	economy.map = map
	add_child(economy)
	economy.workers_requested.connect(_on_workers_requested)
	economy.squad_recruited.connect(_on_squad_recruited)
	DepositLayout.spawn_all(map, economy, map)
	for c in map.features.get(&"mines", []):
		var mine := MineSite.new()
		map.add_child(mine)
		mine.setup(map, c, c == Vector2i(map.width / 2, map.height / 2))
	cards = CardSystem.new()
	cards.name = "Cards"
	add_child(cards)
	cards.setup(economy, GameConfig.MAP_SEED)
	fog = FogOfWar.new()
	fog.name = "FogOfWar"
	add_child(fog)
	fog.setup(map, 0)
	var fx := Effects.new()
	fx.name = "Effects"
	add_child(fx)
	hud.setup(map, camera, economy)
	hud.set_card_system(cards)
	hud.build_requested.connect(selection.start_build)
	hud.recruit_requested.connect(_on_recruit_requested)
	selection.building_selected.connect(hud.on_building_selected)
	selection.economy_system = economy
	selection.build_mode_changed.connect(hud.on_build_mode_changed)
	selection.notify.connect(hud.show_notice)
	selection.map = map
	selection.selection_changed.connect(hud.on_selection_changed)
	selection.controlled_team_changed.connect(hud.on_team_changed)
	selection.controlled_team_changed.connect(func(t): fog.set_team(t); camera.position = map.cell_to_world(map.base_of(t)))
	hud.command.connect(_on_hud_command)
	camera.bounds = Rect2(Vector2.ZERO, map.world_size())
	if GameConfig.SPAWN_TEST_ARMIES:
		_spawn_test_armies()
	camera.position = map.cell_to_world(map.base_of(0) + Vector2i(4, 0))
	camera.set_zoom_level(2.6)
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


## Fin de recrutement : l'escouade apparaît à côté de sa Caserne.
func _on_squad_recruited(barracks: Building, unit: UnitData) -> void:
	var cells := map.spread_cells(barracks.cell, unit.squad_size)
	if cells.size() < unit.squad_size:
		return
	var s := Squad.new()
	squads_root.add_child(s)
	s.setup(unit, barracks.team, map, cells[0], cells)
	selection.notify.emit("%s recruté." % unit.display_name)


## Bouton d'unité de l'onglet Recrutement : Caserne choisie, sinon la moins occupée.
func _on_recruit_requested(unit: UnitData) -> void:
	var team := selection.controlled_team
	var chosen: Building = selection.selected_building
	if not (is_instance_valid(chosen) and chosen.can_recruit(unit)):
		chosen = null
	var err := economy.recruit_error(unit, team, chosen)
	if err != "":
		selection.notify.emit(err)
		return
	var b := economy.recruit(unit, team, chosen)
	selection.notify.emit("%s : recrutement lancé (%d en file)." % [unit.display_name, b.queue.size()])


## Commandes des boutons du HUD.
func _on_hud_command(cmd: StringName) -> void:
	match cmd:
		&"select_all": selection.select_all()
		&"deselect": selection.set_selection([])
		&"stop": selection.stop_selected()
		&"zoom_in": camera.zoom_in()
		&"zoom_out": camera.zoom_out()
		&"switch_team": selection.toggle_team()
		&"move": selection.start_order_mode(SelectionController.OrderMode.MOVE)
		&"attack": selection.start_order_mode(SelectionController.OrderMode.ATTACK)
		&"cancel":
			if cards.player(selection.controlled_team).pending:
				cards.player(selection.controlled_team).cancel_pending()
			else:
				selection.cancel()
		&"center": _center_on_selection()


func _center_on_selection() -> void:
	if selection.selected.is_empty():
		selection.notify.emit("Aucune escouade choisie.")
		return
	var sum := Vector2.ZERO
	for s in selection.selected:
		sum += s.center()
	camera.position = sum / selection.selected.size()
	camera.pan(Vector2.ZERO)
