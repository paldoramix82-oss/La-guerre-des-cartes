class_name UnitDatabase
extends RefCounted
## Charge toutes les définitions d'unités présentes dans res://data/units/.

const UNITS_DIR := "res://data/units/"

static var _cache: Dictionary = {}


static func load_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(UNITS_DIR)
	if dir == null:
		push_error("UnitDatabase : dossier introuvable %s" % UNITS_DIR)
		return _cache
	for file_name in dir.get_files():
		# En build exporté, les ressources apparaissent en ".tres.remap".
		var clean := file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var res := load(UNITS_DIR + clean)
		if res is UnitData:
			_cache[res.id] = res
		else:
			push_warning("UnitDatabase : %s n'est pas un UnitData" % clean)
	return _cache


static func get_unit(id: StringName) -> UnitData:
	return load_all().get(id)
