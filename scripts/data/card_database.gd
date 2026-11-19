class_name CardDatabase
extends RefCounted
## Charge toutes les cartes de res://data/cards/.

const DIR := "res://data/cards/"

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
			if res is CardData:
				_cache[res.id] = res
	return _cache


static func get_card(id: StringName) -> CardData:
	return load_all().get(id)


static func of_category(cat: CardData.Category) -> Array:
	return load_all().values().filter(func(c): return c.category == cat)
