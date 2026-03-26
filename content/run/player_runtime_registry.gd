extends RefCounted
class_name PlayerRuntimeRegistry

static var _active_player: Player


static func set_active_player(player: Player) -> void:
	_active_player = player


static func get_active_player() -> Player:
	return _active_player


static func has_active_player() -> bool:
	return _active_player != null
