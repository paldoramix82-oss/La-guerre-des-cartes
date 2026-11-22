class_name MonsterDatabase
extends RefCounted
## Monstres (data/monsters/) et types de camps (data/camps/).

static var _monsters: Dictionary = {}
static var _camps: Dictionary = {}


static func monsters() -> Dictionary:
	if _monsters.is_empty():
		_monsters = _load("res://data/monsters/")
	return _monsters


static func camps() -> Dictionary:
	if _camps.is_empty():
		_camps = _load("res://data/camps/")
	return _camps


static func get_monster(id: StringName) -> UnitData:
	return monsters().get(id)


static func get_camp(id: StringName) -> MonsterCampData:
	return camps().get(id)


## Types de camps triés du plus faible au plus fort.
static func camps_by_danger() -> Array:
	var list := camps().values()
	list.sort_custom(func(a, b): return a.danger < b.danger)
	return list


static func _load(dir_path: String) -> Dictionary:
	var out := {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		var clean := f.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var res := load(dir_path + clean)
			if res and "id" in res:
				out[res.id] = res
	return out
