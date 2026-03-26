extends Node3D
class_name GlobalMapRoom

const RuntimeState := preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const HeroIconMovementController := preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const FadeTransitionPresenter := preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const TransitionService := preload("res://content/global_map/runtime/global_map_transition_service.gd")
const EventClickHandler := preload("res://content/global_map/presentation/global_map_event_click_handler.gd")

@export_file("*.tscn") var destination_scene_path := "res://scenes/event_room.tscn"

@onready var _camera_map: Camera3D = $camera_map
@onready var _hero_icon: MeshInstance3D = $hero_icon
@onready var _event_icon: MeshInstance3D = $event_icon
@onready var _event_click_area: StaticBody3D = $event_icon/event_click_area
@onready var _fade_rect: ColorRect = $fade_layer/fade_rect

var _state := RuntimeState.new()
var _movement_controller := HeroIconMovementController.new()
var _fade_presenter := FadeTransitionPresenter.new()
var _transition_service := TransitionService.new()
var _click_handler := EventClickHandler.new()


func _ready() -> void:
	if _camera_map != null:
		_camera_map.current = true
	_movement_controller.setup(_hero_icon)
	_fade_presenter.setup(_fade_rect)
	_transition_service.setup(destination_scene_path)
	_click_handler.setup(_camera_map, _event_click_area)


func _unhandled_input(event: InputEvent) -> void:
	if _state.is_traveling or _state.has_arrived:
		return
	if not _click_handler.is_event_clicked(event):
		return
	_state.selected_event_id = "default_event"
	_state.is_traveling = true
	_movement_controller.start_movement(_event_icon.global_position)


func _process(delta: float) -> void:
	if not _state.is_traveling:
		return
	if not _movement_controller.update(delta):
		return
	_state.is_traveling = false
	_state.has_arrived = true
	await _play_enter_room_sequence()


func _play_enter_room_sequence() -> void:
	if _event_icon != null:
		_event_icon.visible = false
	await _fade_presenter.play_fade_to_black(self)
	_transition_service.open_selected_room(get_tree())
