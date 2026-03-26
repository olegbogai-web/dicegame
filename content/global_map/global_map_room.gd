extends Node3D
class_name GlobalMapRoom

const GlobalMapFlowOrchestrator = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3.ONE / 3.0

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


func _process(delta: float) -> void:
	_flow_orchestrator.process(delta)


func _input(event: InputEvent) -> void:
	_flow_orchestrator.handle_input(event)


func throw_global_map_dice() -> void:
	if _board == null:
		return
	var player := GlobalMapRuntimeState.get_player_instance()
	if player == null or player.global_map_dice_loadout.is_empty():
		return
	var requests: Array[DiceThrowRequest] = []
	for dice_definition in player.global_map_dice_loadout:
		if dice_definition == null:
			continue
		var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
		request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
		request.metadata["owner"] = &"global_map"
		request.metadata["definition"] = dice_definition
		requests.append(request)
	if requests.is_empty():
		return
	_board.throw_dice(requests)
