extends Node3D
class_name GlobalMapRoom

const GlobalMapFlowOrchestrator = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")

@onready var _camera: Camera3D = $camera_map
@onready var _background: MeshInstance3D = $background
@onready var _hero_icon: MeshInstance3D = $hero_icon
@onready var _event_icon: MeshInstance3D = $event_icon
@onready var _board: BoardController = $board

var _flow_orchestrator := GlobalMapFlowOrchestrator.new()


func _ready() -> void:
	if _camera != null:
		_camera.current = true
	_flow_orchestrator.configure(self, _camera, _background, _hero_icon, _event_icon, _board)
	if _event_icon != null:
		_event_icon.visible = false


func _process(delta: float) -> void:
	_flow_orchestrator.process(delta)


func _input(event: InputEvent) -> void:
	_flow_orchestrator.handle_input(event)
