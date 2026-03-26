extends RefCounted
class_name GlobalMapRuntimeState

const PlayerScript = preload("res://content/entities/player.gd")
const PlayerBaseStatScript = preload("res://content/entities/player_base_stat.gd")

static var _has_persisted_snapshot := false
static var _persisted_snapshot: Dictionary = {}
static var _active_player: Player
static var _has_opened_global_map_once := false
static var _is_pending_global_map_dice_roll := false

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


static func get_or_create_player() -> Player:
	if _active_player != null:
		return _active_player
	var base_stat := PlayerBaseStatScript.new()
	base_stat.player_id = "default_player"
	base_stat.display_name = "Default Player"
	base_stat.base_cube_global_map = 2
	_active_player = PlayerScript.new(base_stat)
	return _active_player


static func mark_room_completed_before_global_map_enter() -> void:
	_is_pending_global_map_dice_roll = true


static func should_roll_global_map_dice_on_enter() -> bool:
	if not _has_opened_global_map_once:
		_has_opened_global_map_once = true
		_is_pending_global_map_dice_roll = false
		return false
	if not _is_pending_global_map_dice_roll:
		return false
	_is_pending_global_map_dice_roll = false
	return true
