extends Node3D
class_name GlobalMapRoom

const GlobalMapFlowOrchestrator = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const GlobalMapDiceRollService = preload("res://content/global_map/dice/global_map_dice_roll_service.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const GLOBAL_MAP_DICE_ROLL_DELAY := 0.75

@onready var _camera: Camera3D = $camera_map
@onready var _hero_icon: MeshInstance3D = $hero_icon
@onready var _event_icon: MeshInstance3D = $event_icon
@onready var _dash: MeshInstance3D = $dash
@onready var _dash2: MeshInstance3D = $dash2
@onready var _dash3: MeshInstance3D = $dash3
@onready var _board: BoardController = $board

var _flow_orchestrator := GlobalMapFlowOrchestrator.new()


func _ready() -> void:
	if _camera != null:
		_camera.current = true
	_flow_orchestrator.configure(self, _camera, _hero_icon, _event_icon, [_dash, _dash2, _dash3])
	_roll_pending_global_map_dice()


func _process(delta: float) -> void:
	_flow_orchestrator.process(delta)


func _input(event: InputEvent) -> void:
	_flow_orchestrator.handle_input(event)


func _roll_pending_global_map_dice() -> void:
	if _board == null:
		return
	if not GlobalMapRuntimeState.consume_global_map_dice_roll_on_enter():
		return
	_roll_pending_global_map_dice_async()


func _roll_pending_global_map_dice_async() -> void:
	await get_tree().create_timer(GLOBAL_MAP_DICE_ROLL_DELAY).timeout
	var player := GlobalMapRuntimeState.get_player_instance()
	var requests := GlobalMapDiceRollService.build_throw_requests(player, BASE_DICE_SCENE)
	if requests.is_empty():
		return
	var spawned_dice := _board.throw_dice(requests)
	GlobalMapDiceRollService.apply_throw_height_multiplier(spawned_dice)
