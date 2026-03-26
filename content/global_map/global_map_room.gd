extends Node3D
class_name GlobalMapRoom

const GlobalMapFlowOrchestratorScript = preload("res://content/global_map/runtime/global_map_flow_orchestrator.gd")
const GlobalMapClickResolverScript = preload("res://content/global_map/presentation/global_map_click_resolver.gd")
const GlobalMapFadeTransitionPresenterScript = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const HeroIconMovementControllerScript = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")

const ROOM_ENTER_DELAY := 0.15
const FADE_DURATION := 0.45

@onready var _map_root: Node3D = $global_map
@onready var _map_camera: Camera3D = $global_map/camera_map
@onready var _hero_icon: MeshInstance3D = $global_map/hero_icon
@onready var _event_icon: MeshInstance3D = $global_map/event_icon
@onready var _event_room_root: Node3D = $event_room
@onready var _event_room_camera: Camera3D = $event_room/camera_event
@onready var _fade_rect: ColorRect = $ui_transition/fade_rect

var _flow_orchestrator := GlobalMapFlowOrchestratorScript.new()
var _click_resolver := GlobalMapClickResolverScript.new()
var _fade_transition := GlobalMapFadeTransitionPresenterScript.new()
var _hero_movement_controller := HeroIconMovementControllerScript.new()

var _is_transition_started := false


func _ready() -> void:
	_setup_initial_visibility()
	_flow_orchestrator.setup(_hero_icon, _event_icon, _hero_movement_controller)
	_click_resolver.setup(_map_camera, _event_icon)


func _unhandled_input(event: InputEvent) -> void:
	if _is_transition_started:
		return
	if _flow_orchestrator.is_busy():
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if _click_resolver.is_event_icon_clicked(mouse_button.position):
			_flow_orchestrator.begin_move_to_event()


func _process(delta: float) -> void:
	if _is_transition_started:
		return
	if _flow_orchestrator.process_move(delta):
		_start_enter_room_animation()


func _setup_initial_visibility() -> void:
	if _event_room_root != null:
		_event_room_root.visible = false
	if _fade_rect != null:
		_fade_rect.visible = false
		_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	if _map_camera != null:
		_map_camera.current = true


func _start_enter_room_animation() -> void:
	_is_transition_started = true
	await get_tree().create_timer(ROOM_ENTER_DELAY).timeout
	if _event_icon != null:
		_event_icon.visible = false
	await _fade_transition.fade_in(_fade_rect, FADE_DURATION)
	if _map_root != null:
		_map_root.visible = false
	if _event_room_root != null:
		_event_room_root.visible = true
	if _event_room_camera != null:
		_event_room_camera.current = true
