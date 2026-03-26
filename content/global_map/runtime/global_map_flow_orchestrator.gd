extends RefCounted
class_name GlobalMapFlowOrchestrator

const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const GlobalMapEventIconPresenter = preload("res://content/global_map/presentation/global_map_event_icon_presenter.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")

const EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"
const HERO_MOVE_SPEED := 4.75
const EVENT_PICK_RADIUS := 55.0
const PATH_REACHED_EPSILON := 0.02

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
var _is_event_hovered := false


func configure(owner: Node3D, camera: Camera3D, hero_icon: MeshInstance3D, event_icon: MeshInstance3D, road_nodes: Array[Node3D]) -> void:
	_owner = owner
	_camera = camera
	_event_icon = event_icon
	_road_nodes = road_nodes.duplicate()
	_hero_movement.configure(hero_icon)
	_fade_presenter.configure(owner)
	_event_presenter.configure(event_icon)
	_build_path_points()
	_restore_saved_state()


func process(delta: float) -> void:
	if _state.is_transition_in_progress:
		return
	if not _state.hero_move_started:
		return
	if _path_index >= _path_points.size():
		return

	var current_position := _hero_movement.get_world_position()
	var remaining_step := HERO_MOVE_SPEED * delta
	while remaining_step > 0.0 and _path_index < _path_points.size():
		var target_position := _path_points[_path_index]
		_hero_movement.update_direction(current_position, target_position)
		var distance_to_target := current_position.distance_to(target_position)
		if distance_to_target <= PATH_REACHED_EPSILON:
			_hide_passed_road_dash(_path_index)
			_path_index += 1
			continue
		var step := minf(remaining_step, distance_to_target)
		current_position = current_position.move_toward(target_position, step)
		remaining_step -= step
		if step >= distance_to_target:
			_hide_passed_road_dash(_path_index)
			_path_index += 1

	_hero_movement.set_world_position(current_position)
	if _path_index >= _path_points.size():
		_on_event_reached()


func handle_input(event: InputEvent) -> void:
	if _state.is_transition_in_progress:
		return
	if _state.event_reached:
		return
	if _path_points.is_empty():
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		_update_event_hover(mouse_motion.position)
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not _is_event_icon_clicked(mouse_event.position):
		return

	_state.hero_move_started = true
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
		road_node.visible = true
		_path_points.append(road_node.global_position)
	if _event_icon != null:
		_path_points.append(_event_icon.global_position)


func _on_event_reached() -> void:
	if _state.event_reached:
		return
	_state.event_reached = true
	_state.is_transition_in_progress = true
	_save_current_state()
	await _play_enter_room_animation()
	_owner.get_tree().change_scene_to_file(EVENT_ROOM_SCENE_PATH)


func _play_enter_room_animation() -> void:
	_event_presenter.set_hovered(false)
	_hero_movement.snap_to_idle()
	_event_presenter.hide()
	await _fade_presenter.play_fade_out()


func _hide_passed_road_dash(reached_path_index: int) -> void:
	if reached_path_index < 0 or reached_path_index >= _road_nodes.size():
		return
	var road_node := _road_nodes[reached_path_index]
	if road_node == null:
		return
	road_node.visible = false


func _update_event_hover(mouse_position: Vector2) -> void:
	var should_be_hovered := _is_event_icon_clicked(mouse_position)
	if should_be_hovered == _is_event_hovered:
		return
	_is_event_hovered = should_be_hovered
	_event_presenter.set_hovered(_is_event_hovered)


func _save_current_state() -> void:
	var road_visibility: Array[bool] = []
	for road_node in _road_nodes:
		road_visibility.append(road_node != null and road_node.visible)
	_state.save_snapshot({
		"hero_world_position": _hero_movement.get_world_position(),
		"road_visibility": road_visibility,
		"event_visible": _event_icon != null and _event_icon.visible,
		"event_reached": _state.event_reached,
		"hero_move_started": _state.hero_move_started,
	})


func _restore_saved_state() -> void:
	if not _state.has_snapshot():
		return
	var snapshot := _state.load_snapshot()
	var hero_world_position: Vector3 = snapshot.get("hero_world_position", _hero_movement.get_world_position())
	_hero_movement.set_world_position(hero_world_position)

	var road_visibility: Array = snapshot.get("road_visibility", [])
	for index in _road_nodes.size():
		if index >= road_visibility.size():
			break
		var road_node := _road_nodes[index]
		if road_node == null:
			continue
		road_node.visible = bool(road_visibility[index])

	if _event_icon != null:
		_event_icon.visible = bool(snapshot.get("event_visible", _event_icon.visible))
	_state.event_reached = bool(snapshot.get("event_reached", false))
	_state.hero_move_started = bool(snapshot.get("hero_move_started", false))
