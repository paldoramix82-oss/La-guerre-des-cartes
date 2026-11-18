class_name BuildingDatabase
extends RefCounted
## Charge toutes les définitions de bâtiments présentes dans res://data/buildings/.

const BUILDINGS_DIR := "res://data/buildings/"

static var _cache: Dictionary = {}


static func load_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(BUILDINGS_DIR)
	if dir == null:
		push_error("BuildingDatabase : dossier introuvable %s" % BUILDINGS_DIR)
		return _cache
	for file_name in dir.get_files():
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var res := load(BUILDINGS_DIR + clean)
		if res is BuildingData:
			_cache[res.id] = res
	return _cache


static func get_building(id: StringName) -> BuildingData:
	return load_all().get(id)
