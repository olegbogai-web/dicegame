extends Node3D
class_name GlobalMapRoomController

const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const GlobalMapFlowOrchestrator = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")

@export_file("*.tscn") var target_room_scene_path := "res://scenes/event_room.tscn"
@export var hero_straight: Texture2D
@export var hero_back: Texture2D
@export var hero_right: Texture2D

@onready var _camera_map: Camera3D = $camera_map
@onready var _hero_icon: MeshInstance3D = $hero_icon
@onready var _event_icon: MeshInstance3D = $event_icon
@onready var _event_pick_body: CollisionObject3D = $event_icon/event_pick_body
@onready var _fade_rect: ColorRect = $ui/fade_rect

var _runtime_state := GlobalMapRuntimeState.new()
var _flow_orchestrator := GlobalMapFlowOrchestrator.new()


func _ready() -> void:
	if _camera_map != null:
		_camera_map.current = true
	if _hero_icon != null:
		_runtime_state.current_position = _hero_icon.global_position


func _unhandled_input(event: InputEvent) -> void:
	if _runtime_state.is_transition_in_progress:
		return
	if _runtime_state.has_event_been_resolved:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _flow_orchestrator.try_pick_event(_camera_map, mouse_event.position, _event_pick_body):
		return
	_runtime_state.begin_transition()
	await _flow_orchestrator.run_event_transition(self, _hero_icon, _event_icon, _fade_rect, hero_straight, hero_back, hero_right, target_room_scene_path)
	_runtime_state.complete_transition()
