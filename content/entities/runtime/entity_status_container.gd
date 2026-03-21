extends RefCounted
class_name EntityStatusContainer

var _entries: Array[EntityStatusEntry] = []


func add_entry(entry: EntityStatusEntry) -> void:
	if entry == null or entry.definition == null:
		return
	_entries.append(entry)


func get_entries() -> Array[EntityStatusEntry]:
	return _entries.duplicate()


func get_entry(status_id: StringName) -> EntityStatusEntry:
	for entry in _entries:
		if entry != null and entry.get_status_id() == status_id:
			return entry
	return null


func has_status(status_id: StringName) -> bool:
	return get_entry(status_id) != null


func remove_status(status_id: StringName) -> void:
	for index in range(_entries.size() - 1, -1, -1):
		var entry := _entries[index]
		if entry != null and entry.get_status_id() == status_id:
			_entries.remove_at(index)


func clear() -> void:
	_entries.clear()
