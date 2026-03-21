extends RefCounted
class_name EntityDiceLoadout

var _entries: Array[EntityDiceEntry] = []


func add_entry(entry: EntityDiceEntry) -> void:
	if entry == null or entry.definition == null or entry.count <= 0:
		return
	_entries.append(entry)


func get_entries() -> Array[EntityDiceEntry]:
	return _entries.duplicate()


func get_enabled_entries() -> Array[EntityDiceEntry]:
	var enabled: Array[EntityDiceEntry] = []
	for entry in _entries:
		if entry != null and entry.is_enabled and entry.definition != null and entry.count > 0:
			enabled.append(entry)
	return enabled


func get_total_enabled_dice_count() -> int:
	var total := 0
	for entry in get_enabled_entries():
		total += entry.count
	return total


func clear() -> void:
	_entries.clear()
