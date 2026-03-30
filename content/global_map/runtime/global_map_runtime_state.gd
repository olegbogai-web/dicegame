extends RefCounted
class_name GlobalMapRuntimeState

const Player = preload("res://content/entities/player.gd")
const BattleRoom = preload("res://content/rooms/subclasses/battle_room.gd")

static var _has_persisted_snapshot := false
static var _persisted_snapshot: Dictionary = {}
static var _runtime_player: Player
static var _pending_battle_room: BattleRoom

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


static func save_runtime_player(player: Player) -> void:
	_runtime_player = player


static func load_runtime_player() -> Player:
	return _runtime_player


static func save_pending_battle_room(battle_room: BattleRoom) -> void:
	_pending_battle_room = battle_room


static func consume_pending_battle_room() -> BattleRoom:
	var battle_room := _pending_battle_room
	_pending_battle_room = null
	return battle_room
