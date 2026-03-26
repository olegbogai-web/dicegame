extends RefCounted
class_name GlobalMapRuntimeState

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")

static var _has_persisted_snapshot := false
static var _persisted_snapshot: Dictionary = {}
static var _player_instance: Player
static var _should_throw_global_map_dice_on_next_enter := false

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


static func get_player_instance() -> Player:
	if _player_instance == null:
		var battle_room := BattleRoomScript.create_test_battle_room()
		if battle_room != null:
			_player_instance = battle_room.player_instance
	return _player_instance


static func request_global_map_dice_throw_on_next_enter() -> void:
	_should_throw_global_map_dice_on_next_enter = true


static func consume_global_map_dice_throw_request() -> bool:
	var should_throw := _should_throw_global_map_dice_on_next_enter
	_should_throw_global_map_dice_on_next_enter = false
	return should_throw
