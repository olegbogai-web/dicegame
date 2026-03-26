extends Node3D

const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const GlobalMapTransitionService = preload("res://content/global_map/runtime/global_map_transition_service.gd")
const GlobalMapFlowOrchestrator = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")

const CLICK_DISTANCE_THRESHOLD := 75.0

@export var hero_move_speed := 7.5
@export var fade_duration := 0.5

@onready var _camera_map: Camera3D = $camera_map
@onready var _hero_icon: MeshInstance3D = $hero_icon
@onready var _event_icon: MeshInstance3D = $event_icon
@onready var _fade_overlay: ColorRect = $ui_layer/fade_overlay

var _state: GlobalMapRuntimeState
var _flow_orchestrator: GlobalMapFlowOrchestrator


func _ready() -> void:
	if _camera_map != null:
		_camera_map.current = true
	_initialize_state()
	_initialize_flow_orchestrator()


func _process(delta: float) -> void:
	if _flow_orchestrator == null:
		return
	_flow_orchestrator.process_movement(delta, self)


func _unhandled_input(event: InputEvent) -> void:
	if _flow_orchestrator == null:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_click_on_event_icon(mouse_button.position):
		_flow_orchestrator.request_move_to_event()


func _initialize_state() -> void:
	_state = GlobalMapRuntimeState.new()
	if _hero_icon != null:
		_state.hero_position = _hero_icon.position
	if _event_icon != null:
		_state.event_position = _event_icon.position


func _initialize_flow_orchestrator() -> void:
	var hero_controller := HeroIconMovementController.new(_hero_icon, hero_move_speed)
	hero_controller.set_idle_straight()
	var fade_presenter := GlobalMapFadeTransitionPresenter.new(_fade_overlay, fade_duration)
	var transition_service := GlobalMapTransitionService.new()
	_flow_orchestrator = GlobalMapFlowOrchestrator.new(
		_state,
		hero_controller,
		fade_presenter,
		transition_service,
		_event_icon
	)


func _is_click_on_event_icon(click_position: Vector2) -> bool:
	if _camera_map == null or _event_icon == null or not _event_icon.visible:
		return false
	if _camera_map.is_position_behind(_event_icon.global_position):
		return false
	var projected_position := _camera_map.unproject_position(_event_icon.global_position)
	return projected_position.distance_to(click_position) <= CLICK_DISTANCE_THRESHOLD
