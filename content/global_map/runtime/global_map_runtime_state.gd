extends RefCounted
class_name GlobalMapRuntimeState

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")
const TEST_PLAYER_TEXTURE = preload("res://assets/entity/monsters/test_player.png")

static var _has_persisted_snapshot := false
static var _persisted_snapshot: Dictionary = {}
static var _player_instance: Player
static var _player_sprite: Texture2D = TEST_PLAYER_TEXTURE
static var _should_roll_global_map_dice_on_open := false

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


static func set_player_context(player: Player, sprite: Texture2D = null) -> void:
	_player_instance = player
	if sprite != null:
		_player_sprite = sprite


static func get_or_create_player() -> Player:
	if _player_instance == null:
		var test_room := BattleRoomScript.create_test_battle_room()
		if test_room != null:
			_player_instance = test_room.player_instance
	return _player_instance


static func get_player_sprite() -> Texture2D:
	return _player_sprite


static func mark_global_map_should_roll_dice() -> void:
	_should_roll_global_map_dice_on_open = true


static func consume_should_roll_global_map_dice() -> bool:
	if not _should_roll_global_map_dice_on_open:
		return false
	_should_roll_global_map_dice_on_open = false
	return true
