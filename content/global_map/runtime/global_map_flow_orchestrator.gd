extends RefCounted
class_name GlobalMapFlowOrchestrator

const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const GlobalMapEventIconPresenter = preload("res://content/global_map/presentation/global_map_event_icon_presenter.gd")
const GlobalMapMarkerPresenter = preload("res://content/global_map/presentation/global_map_marker_presenter.gd")
const GlobalMapMarkerSpawnService = preload("res://content/global_map/runtime/global_map_marker_spawn_service.gd")
const GlobalMapMarkerRoomLinkResolver = preload("res://content/global_map/routing/global_map_marker_room_link_resolver.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const BattleRoom = preload("res://content/rooms/subclasses/battle_room.gd")
const Player = preload("res://content/entities/player.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const Dice = preload("res://content/dice/dice.gd")
const UNAVAILABLE_MARK_TEXTURE = preload("res://assets/global_map/Х_mark.png")

const START_EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"
const HERO_MOVE_SPEED := 4.75
const EVENT_PICK_RADIUS := 55.0
const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3(5.0, 5.0, 5.0)
const GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER := 4.0
const GLOBAL_MAP_DICE_LOG_PREFIX := "[GlobalMapDice]"
const UNAVAILABLE_MARK_SCALE_MULTIPLIER := 1.3
const UNAVAILABLE_MARK_OFFSET_Y := 0.001
const PATH_DASH_Y := 0.005
const PATH_DASH_STEP := 0.95
const PATH_JITTER_XZ := 0.1
const PATH_JITTER_ROTATION_DEGREES := 10.0
const PATH_MARKER_CLEARANCE := 0.65
const PATH_MAX_BUILD_ATTEMPTS := 60

var _owner: Node3D
var _camera: Camera3D
var _event_icon: MeshInstance3D
var _background: MeshInstance3D
var _board: BoardController
var _road_nodes: Array[Node3D] = []
var _hero_movement := HeroIconMovementController.new()
var _fade_presenter := GlobalMapFadeTransitionPresenter.new()
var _event_presenter := GlobalMapEventIconPresenter.new()
var _marker_presenter := GlobalMapMarkerPresenter.new()
var _marker_spawn_service := GlobalMapMarkerSpawnService.new()
var _marker_link_resolver := GlobalMapMarkerRoomLinkResolver.new()
var _state := GlobalMapRuntimeState.new()
var _rng := RandomNumberGenerator.new()
var _path_points: Array[Vector3] = []
var _start_path_points: Array[Vector3] = []
var _path_index := 0
var _is_event_hovered := false
var _is_global_map_roll_pending := false
var _is_waiting_for_roll_results := false
var _rolled_global_map_dice: Array[Dice] = []
var _pending_room_scene_path := ""
var _event_unavailable_mark: MeshInstance3D
var _dynamic_path_dashes: Array[Node3D] = []
var _path_segments: Array[Dictionary] = []


func configure(
	owner: Node3D,
	camera: Camera3D,
	hero_icon: MeshInstance3D,
	event_icon: MeshInstance3D,
	background: MeshInstance3D,
	road_nodes: Array[Node3D],
	board: BoardController
) -> void:
	_owner = owner
	_camera = camera
	_event_icon = event_icon
	_background = background
	_board = board
	GlobalMapRuntimeState.save_map_scene_path(_owner.scene_file_path)
	_rng.randomize()
	_road_nodes = road_nodes.duplicate()
	_hero_movement.configure(hero_icon)
	_fade_presenter.configure(owner)
	_event_presenter.configure(event_icon)
	_marker_presenter.configure(owner, event_icon, camera)
	_ensure_event_unavailable_mark()
	_build_start_path_points()
	_restore_persisted_state()
	_schedule_global_map_dice_roll_if_needed()


func process(delta: float) -> void:
	_process_global_map_roll_state()
	if _state.is_transition_in_progress:
		return
	if not _state.hero_move_started:
		return
	if _path_index >= _path_points.size():
		return

	var remaining_step := HERO_MOVE_SPEED * delta
	while remaining_step > 0.0 and _path_index < _path_points.size():
		var current_position := _hero_movement.get_ground_position()
		var target_position := _path_points[_path_index]
		_hero_movement.update_direction(current_position, target_position)

		var next_position := current_position.move_toward(target_position, remaining_step)
		var moved_distance := current_position.distance_to(next_position)
		remaining_step -= moved_distance
		_hero_movement.set_world_position(next_position)
		if next_position.distance_to(target_position) > 0.02:
			break
		_path_index += 1
	if _path_index >= _path_points.size():
		_on_target_marker_reached()


func handle_input(event: InputEvent) -> void:
	if _state.is_transition_in_progress:
		return
	if _state.hero_move_started:
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		_update_event_hover(mouse_motion.position)
		_marker_presenter.set_hovered_marker(mouse_motion.position)
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if _try_pick_dynamic_marker(mouse_event.position):
		return
	if _state.event_reached:
		return
	if not _is_event_icon_clicked(mouse_event.position):
		return

	_pending_room_scene_path = START_EVENT_ROOM_SCENE_PATH
	_path_points = _start_path_points.duplicate()
	_path_index = 0
	_state.hero_move_started = true


func _try_pick_dynamic_marker(mouse_position: Vector2) -> bool:
	var picked_marker := _marker_presenter.pick_marker(mouse_position)
	if picked_marker.is_empty():
		return false
	var marker_node := picked_marker.get("node") as Node3D
	if marker_node == null:
		return false
	_pending_room_scene_path = String(picked_marker.get("scene_path", ""))
	var marker_path_points = picked_marker.get("path_points", [])
	if marker_path_points is Array and not (marker_path_points as Array).is_empty():
		_path_points = _to_vector3_array(marker_path_points as Array)
	else:
		_path_points = [marker_node.global_position]
	_path_index = 0
	_state.hero_move_started = true
	return true


func _is_event_icon_clicked(mouse_position: Vector2) -> bool:
	if _camera == null or _event_icon == null:
		return false
	var projected := _camera.unproject_position(_event_icon.global_position)
	return projected.distance_to(mouse_position) <= EVENT_PICK_RADIUS


func _build_start_path_points() -> void:
	_start_path_points.clear()
	for road_node in _road_nodes:
		if road_node == null:
			continue
		road_node.visible = true
		_start_path_points.append(road_node.global_position)
	if _event_icon != null:
		_start_path_points.append(_event_icon.global_position)


func _on_target_marker_reached() -> void:
	if _state.is_transition_in_progress:
		return
	_state.is_transition_in_progress = true
	if _pending_room_scene_path == START_EVENT_ROOM_SCENE_PATH and _path_points.size() == _start_path_points.size():
		_state.event_reached = true
	await _play_enter_room_animation()
	_persist_current_state()
	var next_scene_path := _pending_room_scene_path if not _pending_room_scene_path.is_empty() else START_EVENT_ROOM_SCENE_PATH
	_prepare_pending_runtime_battle_room(next_scene_path)
	_owner.get_tree().change_scene_to_file(next_scene_path)


func _play_enter_room_animation() -> void:
	_event_presenter.set_hovered(false)
	_marker_presenter.clear_hovered_marker()
	_hero_movement.snap_to_idle()
	await _fade_presenter.play_fade_out()


func _update_event_hover(mouse_position: Vector2) -> void:
	var should_be_hovered := not _state.event_reached and _is_event_icon_clicked(mouse_position)
	if should_be_hovered == _is_event_hovered:
		return
	_is_event_hovered = should_be_hovered
	_event_presenter.set_hovered(_is_event_hovered)


func _restore_persisted_state() -> void:
	if not GlobalMapRuntimeState.has_snapshot():
		return
	var snapshot := GlobalMapRuntimeState.load_snapshot()
	_state.hero_move_started = false
	_state.is_transition_in_progress = false
	var saved_position = snapshot.get("hero_world_position", null)
	if saved_position is Vector3:
		_hero_movement.set_world_position(saved_position as Vector3)
	var saved_markers = snapshot.get("markers", [])
	if saved_markers is Array and not saved_markers.is_empty():
		var marker_specs: Array[Dictionary] = []
		for marker_data in saved_markers:
			if marker_data is Dictionary:
				marker_specs.append(marker_data)
		var restored_markers := _marker_presenter.show_markers(marker_specs)
		_rebuild_dynamic_paths(restored_markers)
	else:
		_marker_presenter.clear_dynamic_markers()
		_clear_dynamic_paths()
	var saved_event_reached = snapshot.get("event_reached", false)
	_state.event_reached = bool(saved_event_reached)
	_set_event_unavailable(_state.event_reached)
	_path_points.clear()
	_path_index = 0


func _persist_current_state() -> void:
	var marker_snapshot := _marker_presenter.export_markers_state()
	if _state.is_transition_in_progress:
		for marker_data in marker_snapshot:
			if not marker_data is Dictionary:
				continue
			(marker_data as Dictionary)["unavailable"] = true
	GlobalMapRuntimeState.save_snapshot({
		"hero_world_position": _hero_movement.get_ground_position(),
		"markers": marker_snapshot,
		"event_reached": _state.event_reached,
	})


func _schedule_global_map_dice_roll_if_needed() -> void:
	var should_roll := GlobalMapRuntimeState.has_snapshot()
	if not should_roll:
		print("%s Первый вход на глобальную карту: бросок кубов пропущен." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	var snapshot := GlobalMapRuntimeState.load_snapshot()
	var saved_markers = snapshot.get("markers", [])
	if saved_markers is Array and _has_available_markers(saved_markers):
		print("%s Найдено сохраненное состояние глобальной карты: бросок кубов пропущен." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	_is_global_map_roll_pending = true


func _process_global_map_roll_state() -> void:
	if _is_global_map_roll_pending:
		_is_global_map_roll_pending = false
		_deferred_roll_global_map_dice()
		return
	if not _is_waiting_for_roll_results:
		return
	for dice in _rolled_global_map_dice:
		if dice == null or not is_instance_valid(dice):
			return
		if not dice.has_completed_first_stop():
			return
	_is_waiting_for_roll_results = false
	_spawn_markers_for_roll_result()


func _deferred_roll_global_map_dice() -> void:
	if _board == null:
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но board не найден." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	var player := _resolve_or_create_runtime_player()
	if player == null:
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но игрок не инициализирован." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	if player.runtime_cube_global_map.is_empty():
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но у игрока нет runtime_cube_global_map." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return

	var requests: Array[DiceThrowRequest] = []
	for definition in player.runtime_cube_global_map:
		if definition == null:
			push_warning("%s Игра попыталась бросить куб, но определение куба пустое." % GLOBAL_MAP_DICE_LOG_PREFIX)
			continue
		requests.append(_build_global_map_throw_request(definition))
		print("%s брошен куб (%s)." % [GLOBAL_MAP_DICE_LOG_PREFIX, _format_faces_for_debug(definition)])

	if requests.is_empty():
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но валидных запросов нет." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return

	var spawned_dice := _board.throw_dice(requests)
	if spawned_dice.is_empty():
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но бросок не создал ни одного куба." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	_rolled_global_map_dice.clear()
	for dice_body in spawned_dice:
		if dice_body == null:
			continue
		dice_body.linear_velocity.y *= GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER
		if dice_body is Dice:
			_rolled_global_map_dice.append(dice_body as Dice)
	_is_waiting_for_roll_results = not _rolled_global_map_dice.is_empty()


func _spawn_markers_for_roll_result() -> void:
	if _rolled_global_map_dice.is_empty():
		return
	var marker_points := _marker_spawn_service.build_spawn_points(
		_background,
		_hero_movement.get_ground_position(),
		_rolled_global_map_dice.size()
	)
	if marker_points.is_empty():
		push_warning("%s Не удалось разместить новые метки на карте." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	var marker_specs: Array[Dictionary] = []
	for index in range(min(_rolled_global_map_dice.size(), marker_points.size())):
		var dice := _rolled_global_map_dice[index]
		var marker_data := _marker_link_resolver.resolve_marker_for_face(dice.get_top_face())
		marker_data["position"] = marker_points[index]
		marker_data["visible"] = true
		marker_specs.append(marker_data)
	var created_markers := _marker_presenter.show_markers(marker_specs, false)
	_build_paths_for_markers(created_markers)


func _build_global_map_throw_request(definition: DiceDefinition) -> DiceThrowRequest:
	var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
	request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
	request.metadata["owner"] = "global_map"
	request.metadata["definition"] = definition
	return request


func _resolve_or_create_runtime_player() -> Player:
	var saved_player = GlobalMapRuntimeState.load_runtime_player()
	if saved_player != null:
		saved_player.ensure_runtime_initialized_from_base_stat()
		return saved_player
	var player := BattleRoom.build_default_player()
	GlobalMapRuntimeState.save_runtime_player(player)
	return player


func _prepare_pending_runtime_battle_room(next_scene_path: String) -> void:
	if next_scene_path != GlobalMapMarkerRoomLinkResolver.TEST_BATTLE_ROOM_SCENE_PATH:
		GlobalMapRuntimeState.save_pending_battle_room(null)
		return
	var runtime_player := _resolve_or_create_runtime_player()
	if runtime_player == null:
		push_warning("%s Не удалось подготовить боевую комнату: runtime-игрок не найден." % GLOBAL_MAP_DICE_LOG_PREFIX)
		GlobalMapRuntimeState.save_pending_battle_room(null)
		return
	GlobalMapRuntimeState.save_runtime_player(runtime_player)
	GlobalMapRuntimeState.save_pending_battle_room(BattleRoom.create_runtime_battle_room(runtime_player, _rng))


func _format_faces_for_debug(definition: DiceDefinition) -> String:
	if definition == null:
		return "unknown"
	var values: PackedStringArray = []
	for face in definition.faces:
		if face == null:
			values.append("null")
			continue
		values.append(face.text_value)
	return ", ".join(values)


func _ensure_event_unavailable_mark() -> void:
	if _event_icon == null:
		return
	if _event_unavailable_mark != null and is_instance_valid(_event_unavailable_mark):
		return
	_event_unavailable_mark = MeshInstance3D.new()
	_event_unavailable_mark.mesh = _event_icon.mesh
	_event_unavailable_mark.position = Vector3(0.0, UNAVAILABLE_MARK_OFFSET_Y, 0.0)
	_event_unavailable_mark.scale = Vector3.ONE * UNAVAILABLE_MARK_SCALE_MULTIPLIER
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = UNAVAILABLE_MARK_TEXTURE
	_event_unavailable_mark.material_override = material
	_event_unavailable_mark.visible = false
	_event_icon.add_child(_event_unavailable_mark)


func _set_event_unavailable(is_unavailable: bool) -> void:
	_ensure_event_unavailable_mark()
	if _event_unavailable_mark != null and is_instance_valid(_event_unavailable_mark):
		_event_unavailable_mark.visible = is_unavailable


func _has_available_markers(saved_markers: Array) -> bool:
	for marker_data in saved_markers:
		if not marker_data is Dictionary:
			continue
		if bool((marker_data as Dictionary).get("unavailable", false)):
			continue
		if not bool((marker_data as Dictionary).get("visible", true)):
			continue
		return true
	return false


func _build_paths_for_markers(markers: Array[Dictionary]) -> void:
	if markers.is_empty():
		return
	var marker_positions := _collect_marker_positions(markers)
	var background_bounds := _resolve_background_bounds()
	if background_bounds.is_empty():
		return
	for marker_data in markers:
		var marker_node := marker_data.get("node") as Node3D
		if marker_node == null or not is_instance_valid(marker_node):
			continue
		var path_points := _build_wavy_path_to_marker(marker_node.global_position, marker_positions, background_bounds)
		if path_points.is_empty():
			_marker_presenter.set_marker_path_points(marker_node, [marker_node.global_position])
			continue
		_spawn_dash_path(path_points)
		_marker_presenter.set_marker_path_points(marker_node, path_points)

func _collect_marker_positions(markers: Array[Dictionary]) -> Array[Vector3]:
	var marker_positions: Array[Vector3] = []
	for marker_data in markers:
		var marker_node := marker_data.get("node") as Node3D
		if marker_node == null or not is_instance_valid(marker_node):
			continue
		if not marker_node.visible:
			continue
		marker_positions.append(marker_node.global_position)
	return marker_positions

func _rebuild_dynamic_paths(markers: Array[Dictionary]) -> void:
	_clear_dynamic_paths()
	for marker_data in markers:
		var marker_path = marker_data.get("path_points", [])
		if not marker_path is Array or (marker_path as Array).is_empty():
			continue
		var path_points := _to_vector3_array(marker_path as Array)
		if path_points.size() < 2:
			continue
		_register_path_segments(path_points)
		_spawn_dash_path(path_points)
		var marker_node := marker_data.get("node") as Node3D
		if marker_node != null and is_instance_valid(marker_node):
			_marker_presenter.set_marker_path_points(marker_node, path_points)


func _clear_dynamic_paths() -> void:
	for dash in _dynamic_path_dashes:
		if dash != null and is_instance_valid(dash):
			dash.queue_free()
	_dynamic_path_dashes.clear()
	_path_segments.clear()


func _build_wavy_path_to_marker(target: Vector3, marker_positions: Array[Vector3], background_bounds: Dictionary) -> Array[Vector3]:
	var path_anchor := _resolve_path_anchor()
	for _attempt in PATH_MAX_BUILD_ATTEMPTS:
		var path_points := _generate_wavy_points(path_anchor, target)
		if path_points.size() < 2:
			continue
		if not _is_path_inside_background(path_points, background_bounds):
			continue
		if _path_intersects_markers(path_points, marker_positions, target):
			continue
		if _path_intersects_existing_paths(path_points):
			continue
		_register_path_segments(path_points)
		return path_points
	return []


func _generate_wavy_points(start: Vector3, target: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = [start]
	var start_xz := Vector2(start.x, start.z)
	var target_xz := Vector2(target.x, target.z)
	var total_distance := start_xz.distance_to(target_xz)
	if total_distance < 0.25:
		points.append(Vector3(target.x, PATH_DASH_Y, target.z))
		return points
	var segment_count = max(4, int(ceil(total_distance / 1.1)))
	var direction := (target_xz - start_xz).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var wave_amplitude := clampf(total_distance * 0.08, 0.15, 0.5)
	var wave_frequency := _rng.randf_range(1.4, 2.5)
	var wave_phase := _rng.randf_range(-PI, PI)
	for index in range(1, segment_count):
		var t := float(index) / float(segment_count)
		var base_xz := start_xz.lerp(target_xz, t)
		var envelope := sin(t * PI)
		var offset := sin(t * PI * wave_frequency + wave_phase) * wave_amplitude * envelope
		var point_xz := base_xz + perpendicular * offset
		points.append(Vector3(point_xz.x, PATH_DASH_Y, point_xz.y))
	points.append(Vector3(target.x, PATH_DASH_Y, target.z))
	return points


func _spawn_dash_path(path_points: Array[Vector3]) -> void:
	for segment_index in range(path_points.size() - 1):
		var segment_start := path_points[segment_index]
		var segment_end := path_points[segment_index + 1]
		var segment_length := segment_start.distance_to(segment_end)
		if segment_length <= 0.01:
			continue
		var direction := (segment_end - segment_start).normalized()
		var dash_count = max(1, int(floor(segment_length / PATH_DASH_STEP)))
		for dash_index in range(dash_count):
			var t := (float(dash_index) + 0.5) / float(dash_count)
			var position := segment_start.lerp(segment_end, t)
			position.x += _rng.randf_range(-PATH_JITTER_XZ, PATH_JITTER_XZ)
			position.z += _rng.randf_range(-PATH_JITTER_XZ, PATH_JITTER_XZ)
			position.y = PATH_DASH_Y
			_create_dash_node(position, direction)


func _create_dash_node(position: Vector3, direction: Vector3) -> void:
	var dash_template := _resolve_dash_template()
	if dash_template == null or _owner == null:
		return
	var new_dash := dash_template.duplicate() as MeshInstance3D
	if new_dash == null:
		return
	new_dash.visible = true
	_owner.add_child(new_dash)
	new_dash.global_position = position
	var yaw := atan2(direction.x, direction.z) + (PI * 0.5) + deg_to_rad(_rng.randf_range(-PATH_JITTER_ROTATION_DEGREES, PATH_JITTER_ROTATION_DEGREES))
	new_dash.basis = Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(dash_template.scale)
	_dynamic_path_dashes.append(new_dash)


func _resolve_dash_template() -> MeshInstance3D:
	for road_node in _road_nodes:
		if road_node is MeshInstance3D:
			return road_node as MeshInstance3D
	return null


func _resolve_path_anchor() -> Vector3:
	var anchor := _hero_movement.get_ground_position()
	anchor.y = PATH_DASH_Y
	return anchor


func _resolve_background_bounds() -> Dictionary:
	if not _background is MeshInstance3D:
		return {}
	var mesh_instance := _background as MeshInstance3D
	if mesh_instance.mesh == null:
		return {}
	var local_aabb := mesh_instance.mesh.get_aabb()
	var half_size_x := local_aabb.size.x * 0.5 * absf(mesh_instance.scale.x)
	var half_size_z := local_aabb.size.z * 0.5 * absf(mesh_instance.scale.z)
	var center := mesh_instance.global_position
	return {
		"min_x": center.x - half_size_x,
		"max_x": center.x + half_size_x,
		"min_z": center.z - half_size_z,
		"max_z": center.z + half_size_z,
	}


func _is_path_inside_background(path_points: Array[Vector3], bounds: Dictionary) -> bool:
	var min_x: float = bounds.get("min_x", 0.0)
	var max_x: float = bounds.get("max_x", 0.0)
	var min_z: float = bounds.get("min_z", 0.0)
	var max_z: float = bounds.get("max_z", 0.0)
	for point in path_points:
		if point.x < min_x or point.x > max_x or point.z < min_z or point.z > max_z:
			return false
	return true


func _path_intersects_markers(path_points: Array[Vector3], marker_positions: Array[Vector3], target: Vector3) -> bool:
	for marker_position in marker_positions:
		if marker_position.distance_to(target) <= 0.05:
			continue
		for segment_index in range(path_points.size() - 1):
			var distance := _distance_point_to_segment_2d(
				Vector2(marker_position.x, marker_position.z),
				Vector2(path_points[segment_index].x, path_points[segment_index].z),
				Vector2(path_points[segment_index + 1].x, path_points[segment_index + 1].z)
			)
			if distance < PATH_MARKER_CLEARANCE:
				return true
	return false


func _path_intersects_existing_paths(path_points: Array[Vector3]) -> bool:
	for segment_index in range(path_points.size() - 1):
		var new_start := Vector2(path_points[segment_index].x, path_points[segment_index].z)
		var new_end := Vector2(path_points[segment_index + 1].x, path_points[segment_index + 1].z)
		for existing_segment in _path_segments:
			var existing_start := existing_segment.get("start", Vector2.ZERO) as Vector2
			var existing_end := existing_segment.get("end", Vector2.ZERO) as Vector2
			if _segments_intersect_2d(new_start, new_end, existing_start, existing_end):
				return true
	return false


func _register_path_segments(path_points: Array[Vector3]) -> void:
	for segment_index in range(path_points.size() - 1):
		_path_segments.append({
			"start": Vector2(path_points[segment_index].x, path_points[segment_index].z),
			"end": Vector2(path_points[segment_index + 1].x, path_points[segment_index + 1].z),
		})


func _segments_intersect_2d(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var o1 := _orientation_2d(a1, a2, b1)
	var o2 := _orientation_2d(a1, a2, b2)
	var o3 := _orientation_2d(b1, b2, a1)
	var o4 := _orientation_2d(b1, b2, a2)
	return o1 * o2 < 0.0 and o3 * o4 < 0.0


func _orientation_2d(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)


func _distance_point_to_segment_2d(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var t := clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var projection := segment_start + segment * t
	return point.distance_to(projection)


func _to_vector3_array(values: Array) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for value in values:
		if value is Vector3:
			result.append(value as Vector3)
	return result
