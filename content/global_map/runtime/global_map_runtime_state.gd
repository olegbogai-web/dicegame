extends RefCounted
class_name GlobalMapRuntimeState

static var _has_persisted_snapshot := false
static var _persisted_snapshot: Dictionary = {}
static var _player_instance: Player
static var _roll_global_map_dice_on_enter := false

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


static func set_player_instance(player: Player) -> void:
	_player_instance = player


static func get_player_instance() -> Player:
	return _player_instance


static func queue_global_map_dice_roll_on_enter() -> void:
	_roll_global_map_dice_on_enter = true


static func consume_global_map_dice_roll_on_enter() -> bool:
	var should_roll := _roll_global_map_dice_on_enter
	_roll_global_map_dice_on_enter = false
	return should_roll
