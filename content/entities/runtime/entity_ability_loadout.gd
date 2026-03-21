extends RefCounted
class_name EntityAbilityLoadout

var _entries: Array[EntityAbilityEntry] = []


func add_entry(entry: EntityAbilityEntry) -> void:
	if entry == null or entry.definition == null:
		return
	_entries.append(entry)


func get_entries() -> Array[EntityAbilityEntry]:
	return _entries.duplicate()


func get_entry(ability_id: StringName) -> EntityAbilityEntry:
	for entry in _entries:
		if entry != null and entry.get_ability_id() == ability_id:
			return entry
	return null


func has_ability(ability_id: StringName) -> bool:
	return get_entry(ability_id) != null


func remove_ability(ability_id: StringName) -> void:
	for index in range(_entries.size() - 1, -1, -1):
		var entry := _entries[index]
		if entry != null and entry.get_ability_id() == ability_id:
			_entries.remove_at(index)


func clear() -> void:
	_entries.clear()
