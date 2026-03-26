extends Node3D
class_name GlobalMapRoom

const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const GlobalMapFlowOrchestrator = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")
const GlobalMapTransitionService = preload("res://content/global_map/runtime/global_map_transition_service.gd")
const GlobalMapClickResolver = preload("res://content/global_map/presentation/global_map_click_resolver.gd")
const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")

const TEST_EVENT_ROOM_PATH := "res://scenes/event_room.tscn"

@export var hero_move_speed: float = 8.0
@export var transition_fade_duration: float = 0.5

@onready var _camera_map: Camera3D = $camera_map
@onready var _hero_icon: MeshInstance3D = $hero_icon
@onready var _event_icon: MeshInstance3D = $event_icon
@onready var _event_click_body: CollisionObject3D = $event_icon/event_click_body
@onready var _dash_nodes: Array[Node3D] = [$dash, $dash2, $dash3]
@onready var _fade_rect: ColorRect = $ui/fade_rect

var _runtime_state := GlobalMapRuntimeState.new()
var _flow_orchestrator := GlobalMapFlowOrchestrator.new()
var _transition_service := GlobalMapTransitionService.new()
var _click_resolver := GlobalMapClickResolver.new()
var _hero_movement_controller := HeroIconMovementController.new()
var _fade_presenter := GlobalMapFadeTransitionPresenter.new()


func _ready() -> void:
	if _camera_map != null:
		_camera_map.current = true
	_hero_movement_controller.set_idle_straight(_hero_icon)
	if _fade_rect != null:
		_fade_rect.modulate.a = 0.0
		_fade_rect.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _runtime_state.is_moving or _runtime_state.transition_started:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not _click_resolver.is_event_icon_clicked(_camera_map, mouse_event, _event_click_body):
		return

	_runtime_state.is_moving = true
	await _move_hero_to_event()
	await _play_room_entry_animation()
	_runtime_state.transition_started = true
	_transition_service.open_event_room(get_tree(), TEST_EVENT_ROOM_PATH)


func _move_hero_to_event() -> void:
	var waypoints := _flow_orchestrator.build_road_waypoints(_hero_icon, _dash_nodes, _event_icon)
	await _hero_movement_controller.move_hero_along_path(_hero_icon, waypoints, hero_move_speed)


func _play_room_entry_animation() -> void:
	_hero_movement_controller.set_idle_straight(_hero_icon)
	if _event_icon != null:
		_event_icon.visible = false
	await _fade_presenter.fade_in_out(_fade_rect, transition_fade_duration)
