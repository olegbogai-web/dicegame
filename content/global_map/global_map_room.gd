extends Node3D
class_name GlobalMapRoom

const GlobalMapFlowOrchestrator = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")

@onready var _camera: Camera3D = $camera_map
@onready var _hero_icon: MeshInstance3D = $hero_icon
@onready var _event_icon: MeshInstance3D = $event_icon
@onready var _background: MeshInstance3D = $background
@onready var _dash: MeshInstance3D = $dash
@onready var _dash2: MeshInstance3D = $dash2
@onready var _dash3: MeshInstance3D = $dash3
@onready var _board: BoardController = $board

var _flow_orchestrator := GlobalMapFlowOrchestrator.new()


func _ready() -> void:
	if _camera != null:
		_camera.current = true
	_flow_orchestrator.configure(self, _camera, _hero_icon, _event_icon, _background, [_dash, _dash2, _dash3], _board)


func _process(delta: float) -> void:
	_flow_orchestrator.process(delta)


func _input(event: InputEvent) -> void:
	_flow_orchestrator.handle_input(event)
