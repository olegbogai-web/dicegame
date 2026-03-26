extends RefCounted
class_name GlobalMapRuntimeState

static var _has_persisted_snapshot := false
static var _persisted_snapshot: Dictionary = {}
static var _pending_roll_on_enter := false
static var _pending_roll_delay := 0.0

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


static func schedule_roll_on_next_enter(delay_seconds: float) -> void:
	_pending_roll_on_enter = true
	_pending_roll_delay = maxf(delay_seconds, 0.0)


static func consume_pending_roll_on_enter() -> Dictionary:
	var payload := {
		"should_roll": _pending_roll_on_enter,
		"delay_seconds": _pending_roll_delay,
	}
	_pending_roll_on_enter = false
	_pending_roll_delay = 0.0
	return payload
