extends RefCounted
class_name GlobalMapFlowOrchestrator

const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const GlobalMapEventIconPresenter = preload("res://content/global_map/presentation/global_map_event_icon_presenter.gd")
const GlobalMapMarkerPresenter = preload("res://content/global_map/presentation/global_map_marker_presenter.gd")
const GlobalMapMarkerSpawnService = preload("res://content/global_map/runtime/global_map_marker_spawn_service.gd")
const GlobalMapMarkerRoomLinkResolver = preload("res://content/global_map/routing/global_map_marker_room_link_resolver.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const Player = preload("res://content/entities/player.gd")
const PlayerBaseStat = preload("res://content/entities/player_base_stat.gd")
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
const PATH_SEGMENT_STEP := 0.95
const PATH_SAFE_MARGIN := 0.45
const PATH_MARKER_CLEARANCE := 0.8
const PATH_SWAY_AMPLITUDE := 0.45
const PATH_SWAY_FREQUENCY := 1.25
const PATH_SWAY_ATTEMPTS := 12
const PATH_SEGMENT_INTERSECTION_EPSILON := 0.0001
const DASH_BOB_ROTATION_DEGREES := 10.0
const DASH_BOB_OFFSET := 0.1
const DASH_BOB_SPEED := 2.4

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
var _path_points: Array[Vector3] = []
var _start_path_points: Array[Vector3] = []
var _path_index := 0
var _is_event_hovered := false
var _is_global_map_roll_pending := false
var _is_waiting_for_roll_results := false
var _rolled_global_map_dice: Array[Dice] = []
var _pending_room_scene_path := ""
var _event_unavailable_mark: MeshInstance3D
var _dynamic_path_dashes: Array[MeshInstance3D] = []
var _dynamic_path_segments: Array[Dictionary] = []
var _dynamic_dash_anim_time := 0.0


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
	_process_dynamic_path_dash_animation(delta)
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
		_marker_presenter.show_markers(marker_specs)
		_rebuild_dynamic_paths_to_markers(marker_specs)
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
	_marker_presenter.show_markers(marker_specs, false)
	_rebuild_dynamic_paths_to_markers(marker_specs)


func _build_global_map_throw_request(definition: DiceDefinition) -> DiceThrowRequest:
	var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
	request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
	request.metadata["owner"] = "global_map"
	request.metadata["definition"] = definition
	return request


func _resolve_or_create_runtime_player() -> Player:
	var saved_player = GlobalMapRuntimeState.load_runtime_player()
	if saved_player != null:
		return saved_player
	var base_stat := PlayerBaseStat.new()
	base_stat.player_id = "global_map_runtime_player"
	base_stat.display_name = "GlobalMapRuntimePlayer"
	var player := Player.new(base_stat)
	GlobalMapRuntimeState.save_runtime_player(player)
	return player


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


func _rebuild_dynamic_paths_to_markers(marker_specs: Array[Dictionary]) -> void:
	_clear_dynamic_paths()
	if _owner == null or _background == null or _road_nodes.is_empty():
		return
	var template_dash := _resolve_template_dash()
	if template_dash == null:
		return
	var bounds := _resolve_background_bounds(_background)
	if bounds.is_empty():
		return
	var origin := _hero_movement.get_ground_position()
	origin.y = PATH_DASH_Y
	var marker_positions: Array[Vector3] = []
	for marker_spec in marker_specs:
		if not marker_spec is Dictionary:
			continue
		var marker_position = marker_spec.get("position", null)
		if marker_position is Vector3:
			var marker_vec := marker_position as Vector3
			marker_vec.y = PATH_DASH_Y
			marker_positions.append(marker_vec)
	for marker_position in marker_positions:
		var polyline := _build_non_intersecting_marker_path(origin, marker_position, marker_positions, bounds)
		if polyline.size() < 2:
			continue
		_append_path_segments(polyline)
		_spawn_path_dashes(template_dash, polyline)


func _process_dynamic_path_dash_animation(delta: float) -> void:
	if _dynamic_path_dashes.is_empty():
		return
	_dynamic_dash_anim_time += delta
	for index in range(_dynamic_path_dashes.size()):
		var dash := _dynamic_path_dashes[index]
		if dash == null or not is_instance_valid(dash):
			continue
		var base_transform := dash.get_meta(&"path_base_transform", dash.global_transform)
		if not base_transform is Transform3D:
			continue
		var transform := base_transform as Transform3D
		var phase := _dynamic_dash_anim_time * DASH_BOB_SPEED + float(index) * 0.65
		var offset_x := sin(phase) * DASH_BOB_OFFSET
		var offset_z := cos(phase * 0.85) * DASH_BOB_OFFSET
		var rotation_y := deg_to_rad(sin(phase * 1.1) * DASH_BOB_ROTATION_DEGREES)
		var new_origin := transform.origin + Vector3(offset_x, 0.0, offset_z)
		var rotated_basis := transform.basis * Basis(Vector3.UP, rotation_y)
		dash.global_transform = Transform3D(rotated_basis, new_origin)


func _clear_dynamic_paths() -> void:
	for dash in _dynamic_path_dashes:
		if dash != null and is_instance_valid(dash):
			dash.queue_free()
	_dynamic_path_dashes.clear()
	_dynamic_path_segments.clear()


func _resolve_template_dash() -> MeshInstance3D:
	for road_node in _road_nodes:
		if road_node is MeshInstance3D:
			return road_node as MeshInstance3D
	return null


func _spawn_path_dashes(template_dash: MeshInstance3D, polyline: Array[Vector3]) -> void:
	if template_dash == null:
		return
	for segment_index in range(polyline.size() - 1):
		var segment_start := polyline[segment_index]
		var segment_end := polyline[segment_index + 1]
		var direction := segment_end - segment_start
		var segment_length := direction.length()
		if segment_length <= 0.001:
			continue
		var segment_forward := direction / segment_length
		var step_count := int(floor(segment_length / PATH_SEGMENT_STEP))
		for step_index in range(step_count + 1):
			var distance := min(step_index * PATH_SEGMENT_STEP, segment_length)
			if segment_index > 0 and step_index == 0:
				continue
			var dash_transform := _build_dash_transform(template_dash, segment_start + segment_forward * distance, segment_forward)
			var dash := MeshInstance3D.new()
			dash.mesh = template_dash.mesh
			dash.scale = template_dash.scale
			dash.material_override = template_dash.material_override
			dash.cast_shadow = template_dash.cast_shadow
			dash.visible = true
			_owner.add_child(dash)
			dash.global_transform = dash_transform
			dash.set_meta(&"path_base_transform", dash_transform)
			_dynamic_path_dashes.append(dash)


func _build_dash_transform(template_dash: MeshInstance3D, position: Vector3, forward: Vector3) -> Transform3D:
	var base_basis := template_dash.global_transform.basis
	var up := Vector3.UP
	var look_basis := Basis.looking_at(forward, up)
	return Transform3D(look_basis * base_basis, Vector3(position.x, PATH_DASH_Y, position.z))


func _build_non_intersecting_marker_path(
	origin: Vector3,
	target: Vector3,
	all_markers: Array[Vector3],
	bounds: Dictionary
) -> Array[Vector3]:
	for attempt in range(PATH_SWAY_ATTEMPTS):
		var amplitude := PATH_SWAY_AMPLITUDE * (1.0 + float(attempt) * 0.18)
		var frequency := PATH_SWAY_FREQUENCY + float(attempt % 3) * 0.45
		var direction_sign := -1.0 if attempt % 2 == 1 else 1.0
		var path := _build_wavy_polyline(origin, target, bounds, amplitude * direction_sign, frequency)
		if path.size() < 2:
			continue
		if _path_conflicts_with_existing(path, all_markers, target):
			continue
		return path
	return [origin, target]


func _build_wavy_polyline(
	origin: Vector3,
	target: Vector3,
	bounds: Dictionary,
	amplitude: float,
	frequency: float
) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var line := target - origin
	var distance := line.length()
	if distance <= 0.001:
		return path
	var direction := line / distance
	var perpendicular := Vector3(-direction.z, 0.0, direction.x).normalized()
	var step_count := max(int(ceil(distance / PATH_SEGMENT_STEP)), 1)
	for step_index in range(step_count + 1):
		var t := float(step_index) / float(step_count)
		var base_point := origin.lerp(target, t)
		var wave_offset := sin(t * PI * frequency) * amplitude
		var candidate := base_point + perpendicular * wave_offset
		candidate.x = clampf(candidate.x, bounds["min_x"] + PATH_SAFE_MARGIN, bounds["max_x"] - PATH_SAFE_MARGIN)
		candidate.z = clampf(candidate.z, bounds["min_z"] + PATH_SAFE_MARGIN, bounds["max_z"] - PATH_SAFE_MARGIN)
		candidate.y = PATH_DASH_Y
		path.append(candidate)
	path[0] = Vector3(origin.x, PATH_DASH_Y, origin.z)
	path[path.size() - 1] = Vector3(target.x, PATH_DASH_Y, target.z)
	return path


func _path_conflicts_with_existing(path: Array[Vector3], all_markers: Array[Vector3], target: Vector3) -> bool:
	for marker in all_markers:
		if marker.distance_to(target) <= 0.001:
			continue
		if _path_too_close_to_point(path, marker, PATH_MARKER_CLEARANCE):
			return true
	for segment_index in range(path.size() - 1):
		var a := path[segment_index]
		var b := path[segment_index + 1]
		for existing_segment in _dynamic_path_segments:
			var c := existing_segment.get("from", null)
			var d := existing_segment.get("to", null)
			if not c is Vector3 or not d is Vector3:
				continue
			if _segments_intersect_2d(a, b, c as Vector3, d as Vector3):
				return true
	return false


func _append_path_segments(path: Array[Vector3]) -> void:
	for segment_index in range(path.size() - 1):
		_dynamic_path_segments.append({
			"from": path[segment_index],
			"to": path[segment_index + 1],
		})


func _path_too_close_to_point(path: Array[Vector3], point: Vector3, min_distance: float) -> bool:
	for segment_index in range(path.size() - 1):
		var a := path[segment_index]
		var b := path[segment_index + 1]
		if _distance_point_to_segment_2d(point, a, b) < min_distance:
			return true
	return false


func _distance_point_to_segment_2d(point: Vector3, start: Vector3, end: Vector3) -> float:
	var segment := Vector2(end.x - start.x, end.z - start.z)
	var point_vector := Vector2(point.x - start.x, point.z - start.z)
	var len_sq := segment.length_squared()
	if len_sq <= PATH_SEGMENT_INTERSECTION_EPSILON:
		return Vector2(point.x - start.x, point.z - start.z).length()
	var projection := clampf(point_vector.dot(segment) / len_sq, 0.0, 1.0)
	var closest := Vector2(start.x, start.z) + segment * projection
	return Vector2(point.x, point.z).distance_to(closest)


func _segments_intersect_2d(a_start: Vector3, a_end: Vector3, b_start: Vector3, b_end: Vector3) -> bool:
	var a1 := Vector2(a_start.x, a_start.z)
	var a2 := Vector2(a_end.x, a_end.z)
	var b1 := Vector2(b_start.x, b_start.z)
	var b2 := Vector2(b_end.x, b_end.z)
	if a1.distance_to(b1) <= PATH_SEGMENT_INTERSECTION_EPSILON:
		return false
	if a1.distance_to(b2) <= PATH_SEGMENT_INTERSECTION_EPSILON:
		return false
	if a2.distance_to(b1) <= PATH_SEGMENT_INTERSECTION_EPSILON:
		return false
	if a2.distance_to(b2) <= PATH_SEGMENT_INTERSECTION_EPSILON:
		return false
	return Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null


func _resolve_background_bounds(background_node: Node3D) -> Dictionary:
	if not background_node is MeshInstance3D:
		return {}
	var mesh_instance := background_node as MeshInstance3D
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
