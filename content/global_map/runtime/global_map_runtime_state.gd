extends RefCounted
class_name GlobalMapRuntimeState

static var _snapshot: Dictionary = {}

var is_transition_in_progress := false
var event_reached := false
var hero_move_started := false


func save_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)


func has_snapshot() -> bool:
	return not _snapshot.is_empty()


func load_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func clear_snapshot() -> void:
	_snapshot.clear()
