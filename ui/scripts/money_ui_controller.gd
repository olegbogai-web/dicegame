extends CanvasLayer
class_name MoneyUiController

const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const Player = preload("res://content/entities/player.gd")

@onready var _coins_label: Label = $container/number_of_coins

var _bound_player: Player


func _ready() -> void:
	_process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_player_binding()
	_update_coin_text()


func _process(_delta: float) -> void:
	_refresh_player_binding()


func _exit_tree() -> void:
	_disconnect_player_signal()


func _refresh_player_binding() -> void:
	var next_player := _resolve_runtime_player()
	if next_player == _bound_player:
		return
	_disconnect_player_signal()
	_bound_player = next_player
	if _bound_player != null and not _bound_player.coins_changed.is_connected(_on_player_coins_changed):
		_bound_player.coins_changed.connect(_on_player_coins_changed)
	_update_coin_text()


func _disconnect_player_signal() -> void:
	if _bound_player != null and _bound_player.coins_changed.is_connected(_on_player_coins_changed):
		_bound_player.coins_changed.disconnect(_on_player_coins_changed)


func _resolve_runtime_player() -> Player:
	var tree := get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene
	if current_scene != null:
		var battle_room = current_scene.get("battle_room_data")
		if battle_room != null:
			var battle_player := battle_room.player_instance as Player
			if battle_player != null:
				return battle_player
	return GlobalMapRuntimeState.load_runtime_player()


func _on_player_coins_changed(_coins: int) -> void:
	_update_coin_text()


func _update_coin_text() -> void:
	if _coins_label == null:
		return
	var coins := 0
	if _bound_player != null:
		coins = _bound_player.get_current_coins()
	_coins_label.text = str(coins)
