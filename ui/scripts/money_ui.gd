extends CanvasLayer
class_name MoneyUi

const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const Player = preload("res://content/entities/player.gd")

@onready var _coins_label: Label = $number_of_coins

var _bound_player: Player


func _ready() -> void:
	_refresh_label(0)
	_try_bind_runtime_player()


func _process(_delta: float) -> void:
	if _bound_player != null:
		return
	_try_bind_runtime_player()


func bind_player(player: Player) -> void:
	if _bound_player != null and _bound_player.coins_changed.is_connected(_on_player_coins_changed):
		_bound_player.coins_changed.disconnect(_on_player_coins_changed)
	_bound_player = player
	if _bound_player == null:
		_refresh_label(0)
		return
	if not _bound_player.coins_changed.is_connected(_on_player_coins_changed):
		_bound_player.coins_changed.connect(_on_player_coins_changed)
	_refresh_label(_bound_player.current_coins)


func _try_bind_runtime_player() -> void:
	var runtime_player := GlobalMapRuntimeState.load_runtime_player()
	if runtime_player == null:
		return
	bind_player(runtime_player)


func _on_player_coins_changed(total_coins: int) -> void:
	_refresh_label(total_coins)


func _refresh_label(total_coins: int) -> void:
	if _coins_label == null:
		return
	_coins_label.text = str(maxi(total_coins, 0))
