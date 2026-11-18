class_name DepositDatabase
extends RefCounted
## Charge les types de gisements de res://data/deposits/.

const DIR := "res://data/deposits/"

static var _cache: Dictionary = {}


static func load_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(DIR)
	if dir == null:
		return _cache
	for file_name in dir.get_files():
		var clean := file_name.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var res := load(DIR + clean)
			if res is DepositData:
				_cache[res.id] = res
	return _cache


static func get_deposit(id: StringName) -> DepositData:
	return load_all().get(id)
