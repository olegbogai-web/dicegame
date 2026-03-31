extends Node3D
class_name GlobalMapRoom

const GlobalMapFlowOrchestrator = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")

@onready var _camera: Camera3D = $camera_map
@onready var _hero_icon: MeshInstance3D = $hero_icon
@onready var _event_icon: MeshInstance3D = $event_icon
@onready var _background: MeshInstance3D = $background
@onready var _dash: MeshInstance3D = $dash
@onready var _dash2: MeshInstance3D = $dash2
@onready var _dash3: MeshInstance3D = $dash3
@onready var _board: BoardController = $board
@onready var _coin_counter_label: Label3D = $coin/number_of_coins

var _flow_orchestrator := GlobalMapFlowOrchestrator.new()
var _bound_runtime_player: Player


func _ready() -> void:
	if _camera != null:
		_camera.current = true
	_flow_orchestrator.configure(self, _camera, _hero_icon, _event_icon, _background, [_dash, _dash2, _dash3], _board)
	_bind_runtime_player_money_counter()


func _process(delta: float) -> void:
	_bind_runtime_player_money_counter()
	_flow_orchestrator.process(delta)


func _input(event: InputEvent) -> void:
	_flow_orchestrator.handle_input(event)


func _exit_tree() -> void:
	if _bound_runtime_player != null and _bound_runtime_player.runtime_money_changed.is_connected(_on_runtime_player_money_changed):
		_bound_runtime_player.runtime_money_changed.disconnect(_on_runtime_player_money_changed)
	_bound_runtime_player = null


func _bind_runtime_player_money_counter() -> void:
	var runtime_player := GlobalMapRuntimeState.load_runtime_player()
	if runtime_player == _bound_runtime_player:
		_update_money_counter_label(runtime_player.runtime_money if runtime_player != null else 0)
		return
	if _bound_runtime_player != null and _bound_runtime_player.runtime_money_changed.is_connected(_on_runtime_player_money_changed):
		_bound_runtime_player.runtime_money_changed.disconnect(_on_runtime_player_money_changed)
	_bound_runtime_player = runtime_player
	if _bound_runtime_player != null and not _bound_runtime_player.runtime_money_changed.is_connected(_on_runtime_player_money_changed):
		_bound_runtime_player.runtime_money_changed.connect(_on_runtime_player_money_changed)
	_update_money_counter_label(_bound_runtime_player.runtime_money if _bound_runtime_player != null else 0)


func _on_runtime_player_money_changed(new_value: int) -> void:
	_update_money_counter_label(new_value)


func _update_money_counter_label(new_value: int) -> void:
	if _coin_counter_label == null:
		return
	_coin_counter_label.text = str(maxi(new_value, 0))
