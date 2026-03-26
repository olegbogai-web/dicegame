extends RefCounted
class_name GlobalMapRuntimeState

static var _has_persisted_snapshot := false
static var _persisted_snapshot: Dictionary = {}
static var _runtime_player: Player
static var _has_pending_global_map_roll := false
static var _pending_global_map_roll: Dictionary = {}

var is_transition_in_progress := false
var event_reached := false
var hero_move_started := false


static func save_snapshot(snapshot: Dictionary) -> void:
	_persisted_snapshot = snapshot.duplicate(true)
	_has_persisted_snapshot = true


static func has_snapshot() -> bool:
	return _has_persisted_snapshot


static func load_snapshot() -> Dictionary:
	return _persisted_snapshot.duplicate(true)


static func clear_snapshot() -> void:
	_persisted_snapshot.clear()
	_has_persisted_snapshot = false


static func set_runtime_player(player: Player) -> void:
	_runtime_player = player


static func get_runtime_player() -> Player:
	return _runtime_player


static func queue_pending_global_map_roll(roll_payload: Dictionary) -> void:
	_pending_global_map_roll = roll_payload.duplicate(true)
	_has_pending_global_map_roll = true


static func has_pending_global_map_roll() -> bool:
	return _has_pending_global_map_roll


static func consume_pending_global_map_roll() -> Dictionary:
	if not _has_pending_global_map_roll:
		return {}
	var payload := _pending_global_map_roll.duplicate(true)
	_pending_global_map_roll.clear()
	_has_pending_global_map_roll = false
	return payload
