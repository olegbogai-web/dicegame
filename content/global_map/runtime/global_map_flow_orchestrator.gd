extends RefCounted
class_name GlobalMapFlowOrchestrator

const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const GlobalMapEventIconPresenter = preload("res://content/global_map/presentation/global_map_event_icon_presenter.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")

const EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"
const HERO_MOVE_SPEED := 9.5
const EVENT_PICK_RADIUS := 55.0

var _owner: Node3D
var _camera: Camera3D
var _event_icon: MeshInstance3D
var _road_nodes: Array[Node3D] = []
var _hero_movement := HeroIconMovementController.new()
var _fade_presenter := GlobalMapFadeTransitionPresenter.new()
var _event_presenter := GlobalMapEventIconPresenter.new()
var _state := GlobalMapRuntimeState.new()
var _path_points: Array[Vector3] = []
var _path_index := 0


func configure(owner: Node3D, camera: Camera3D, hero_icon: MeshInstance3D, event_icon: MeshInstance3D, road_nodes: Array[Node3D]) -> void:
	_owner = owner
	_camera = camera
	_event_icon = event_icon
	_road_nodes = road_nodes.duplicate()
	_hero_movement.configure(hero_icon)
	_fade_presenter.configure(owner)
	_event_presenter.configure(event_icon)
	_build_path_points()


func process(delta: float) -> void:
	if _state.is_transition_in_progress:
		return
	if _path_index >= _path_points.size():
		return

	var current_position := _hero_movement.get_world_position()
	var target_position := _path_points[_path_index]
	_hero_movement.update_direction(current_position, target_position)

	var next_position := current_position.move_toward(target_position, HERO_MOVE_SPEED * delta)
	_hero_movement.set_world_position(next_position)
	if next_position.distance_to(target_position) <= 0.02:
		_path_index += 1
		if _path_index >= _path_points.size():
			_on_event_reached()


func handle_input(event: InputEvent) -> void:
	if _state.is_transition_in_progress:
		return
	if _state.event_reached:
		return
	if _path_points.is_empty():
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not _is_event_icon_clicked(mouse_event.position):
		return

	_path_index = 0


func _is_event_icon_clicked(mouse_position: Vector2) -> bool:
	if _camera == null or _event_icon == null:
		return false
	if not _event_icon.visible:
		return false
	var projected := _camera.unproject_position(_event_icon.global_position)
	return projected.distance_to(mouse_position) <= EVENT_PICK_RADIUS


func _build_path_points() -> void:
	_path_points.clear()
	for road_node in _road_nodes:
		if road_node == null:
			continue
		_path_points.append(road_node.global_position)
	if _event_icon != null:
		_path_points.append(_event_icon.global_position)


func _on_event_reached() -> void:
	if _state.event_reached:
		return
	_state.event_reached = true
	_state.is_transition_in_progress = true
	await _play_enter_room_animation()
	_owner.get_tree().change_scene_to_file(EVENT_ROOM_SCENE_PATH)


func _play_enter_room_animation() -> void:
	_hero_movement.snap_to_idle()
	_event_presenter.hide()
	await _fade_presenter.play_fade_out()
