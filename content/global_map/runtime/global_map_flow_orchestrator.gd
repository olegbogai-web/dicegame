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
const DASH_PATH_SPAWN_Y := 0.005
const DASH_PATH_POINT_SPACING := 0.85
const DASH_PATH_MARGIN_FROM_BOUNDS := 0.45
const DASH_PATH_MIN_MARKER_CLEARANCE := 0.6
const DASH_PATH_OFFSET_AMPLITUDE := 0.35
const DASH_PATH_JITTER_POSITION := 0.1
const DASH_PATH_JITTER_ROTATION_DEGREES := 10.0
const DASH_PATH_BUILD_ATTEMPTS := 10
const DASH_EDGE_SPACING_MIN := 0.3
const DASH_EDGE_SPACING_MAX := 0.5

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
var _path_dash_template: MeshInstance3D
var _dynamic_path_dashes: Array[MeshInstance3D] = []


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
	_path_dash_template = _road_nodes[0] as MeshInstance3D if not _road_nodes.is_empty() else null
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
	else:
		_marker_presenter.clear_dynamic_markers()
	var saved_event_reached = snapshot.get("event_reached", false)
	_state.event_reached = bool(saved_event_reached)
	_set_event_unavailable(_state.event_reached)
	_rebuild_dynamic_marker_paths()
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
	_rebuild_dynamic_marker_paths()


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


func _rebuild_dynamic_marker_paths() -> void:
	_clear_dynamic_marker_paths()
	var start_position := _hero_movement.get_ground_position()
	var marker_points := _marker_presenter.get_active_marker_points(false)
	if marker_points.is_empty():
		return
	var bounds := _resolve_background_bounds()
	if bounds.is_empty():
		return
	var occupied_segments: Array[Dictionary] = []
	for marker_point in marker_points:
		var waypoints := _build_non_intersecting_path_points(start_position, marker_point, marker_points, occupied_segments, bounds)
		if waypoints.size() < 2:
			continue
		_spawn_dash_path(waypoints)
		for index in range(waypoints.size() - 1):
			occupied_segments.append({
				"from": waypoints[index],
				"to": waypoints[index + 1],
			})


func _clear_dynamic_marker_paths() -> void:
	for dash in _dynamic_path_dashes:
		if dash == null or not is_instance_valid(dash):
			continue
		dash.queue_free()
	_dynamic_path_dashes.clear()


func _build_non_intersecting_path_points(
	start_position: Vector3,
	target_position: Vector3,
	all_markers: Array[Vector3],
	occupied_segments: Array[Dictionary],
	bounds: Dictionary
) -> Array[Vector3]:
	var direction := target_position - start_position
	var distance := direction.length()
	if distance < 0.2:
		return [start_position, target_position]
	var waypoint_count := maxi(2, int(distance / DASH_PATH_POINT_SPACING))
	var safe_start := Vector3(start_position.x, DASH_PATH_SPAWN_Y, start_position.z)
	var safe_target := Vector3(target_position.x, DASH_PATH_SPAWN_Y, target_position.z)
	for _attempt in DASH_PATH_BUILD_ATTEMPTS:
		var points: Array[Vector3] = [safe_start]
		var previous_point := safe_start
		var can_build := true
		var perpendicular := Vector3(-direction.z, 0.0, direction.x).normalized()
		var wave_phase := randf_range(0.0, PI * 2.0)
		var wave_multiplier := randf_range(0.65, 1.35)
		for index in range(1, waypoint_count):
			var t := float(index) / float(waypoint_count)
			var base_point := safe_start.lerp(safe_target, t)
			var wave := sin((t * PI * 2.0 * wave_multiplier) + wave_phase) * DASH_PATH_OFFSET_AMPLITUDE
			var candidate := base_point + perpendicular * wave
			candidate = _clamp_point_to_bounds(candidate, bounds)
			if _segment_is_blocked(previous_point, candidate, target_position, all_markers, occupied_segments):
				can_build = false
				break
			points.append(candidate)
			previous_point = candidate
		if not can_build:
			continue
		if _segment_is_blocked(previous_point, safe_target, target_position, all_markers, occupied_segments):
			continue
		points.append(safe_target)
		return points
	return [safe_start, safe_target]


func _spawn_dash_path(path_points: Array[Vector3]) -> void:
	if _owner == null:
		return
	if _path_dash_template == null or not is_instance_valid(_path_dash_template):
		return
	if not _path_dash_template is MeshInstance3D:
		return
	var template := _path_dash_template as MeshInstance3D
	var dash_length := _resolve_dash_length(template)
	var edge_gap := randf_range(DASH_EDGE_SPACING_MIN, DASH_EDGE_SPACING_MAX)
	var center_spacing := maxf(0.05, dash_length + edge_gap)
	var sampled_points := _sample_dash_positions(path_points, center_spacing)
	if sampled_points.size() < 2:
		return

	for index in range(sampled_points.size() - 1):
		var base_position := sampled_points[index]
		var target_position := sampled_points[index + 1]
		var dash := MeshInstance3D.new()
		dash.mesh = template.mesh
		dash.scale = template.scale
		dash.material_override = template.material_override
		var jittered_position := Vector3(
			base_position.x + randf_range(-DASH_PATH_JITTER_POSITION, DASH_PATH_JITTER_POSITION),
			DASH_PATH_SPAWN_Y,
			base_position.z + randf_range(-DASH_PATH_JITTER_POSITION, DASH_PATH_JITTER_POSITION)
		)
		var yaw := _resolve_dash_yaw(jittered_position, target_position)
		yaw += deg_to_rad(randf_range(-DASH_PATH_JITTER_ROTATION_DEGREES, DASH_PATH_JITTER_ROTATION_DEGREES))
		dash.global_position = jittered_position
		dash.rotation = Vector3(0.0, yaw, 0.0)
		_owner.add_child(dash)
		_dynamic_path_dashes.append(dash)


func _resolve_dash_length(template: MeshInstance3D) -> float:
	if template == null or template.mesh == null:
		return 0.4
	var local_aabb := template.mesh.get_aabb()
	return maxf(0.05, local_aabb.size.x * absf(template.scale.x))


func _sample_dash_positions(path_points: Array[Vector3], center_spacing: float) -> Array[Vector3]:
	var sampled: Array[Vector3] = []
	if path_points.size() < 2:
		return sampled
	var remaining := 0.0
	var first := path_points[0]
	first.y = DASH_PATH_SPAWN_Y
	sampled.append(first)
	for index in range(path_points.size() - 1):
		var segment_start := path_points[index]
		var segment_end := path_points[index + 1]
		segment_start.y = DASH_PATH_SPAWN_Y
		segment_end.y = DASH_PATH_SPAWN_Y
		var segment := segment_end - segment_start
		var segment_length := segment.length()
		if segment_length <= 0.000001:
			continue
		var direction := segment / segment_length
		var distance_on_segment := center_spacing - remaining
		while distance_on_segment < segment_length:
			var point := segment_start + direction * distance_on_segment
			point.y = DASH_PATH_SPAWN_Y
			sampled.append(point)
			distance_on_segment += center_spacing
		remaining = segment_length - (distance_on_segment - center_spacing)
	var finish := path_points[path_points.size() - 1]
	finish.y = DASH_PATH_SPAWN_Y
	if sampled[sampled.size() - 1].distance_to(finish) >= center_spacing * 0.35:
		sampled.append(finish)
	return sampled


func _resolve_dash_yaw(from_position: Vector3, to_position: Vector3) -> float:
	var direction := to_position - from_position
	direction.y = 0.0
	if direction.length_squared() <= 0.000001:
		return 0.0
	return -atan2(direction.z, direction.x)


func _segment_is_blocked(
	segment_start: Vector3,
	segment_end: Vector3,
	target_marker: Vector3,
	all_markers: Array[Vector3],
	occupied_segments: Array[Dictionary]
) -> bool:
	for marker_point in all_markers:
		if marker_point == target_marker:
			continue
		if _distance_point_to_segment_xz(marker_point, segment_start, segment_end) < DASH_PATH_MIN_MARKER_CLEARANCE:
			return true
	for segment_data in occupied_segments:
		var occupied_start = segment_data.get("from", null)
		var occupied_end = segment_data.get("to", null)
		if not occupied_start is Vector3 or not occupied_end is Vector3:
			continue
		if _segments_intersect_xz(segment_start, segment_end, occupied_start as Vector3, occupied_end as Vector3):
			return true
	return false


func _resolve_background_bounds() -> Dictionary:
	if _background == null or not _background is MeshInstance3D:
		return {}
	var mesh_instance := _background as MeshInstance3D
	if mesh_instance.mesh == null:
		return {}
	var local_aabb := mesh_instance.mesh.get_aabb()
	var half_size_x := local_aabb.size.x * 0.5 * absf(mesh_instance.scale.x)
	var half_size_z := local_aabb.size.z * 0.5 * absf(mesh_instance.scale.z)
	var center := mesh_instance.global_position
	return {
		"min_x": center.x - half_size_x + DASH_PATH_MARGIN_FROM_BOUNDS,
		"max_x": center.x + half_size_x - DASH_PATH_MARGIN_FROM_BOUNDS,
		"min_z": center.z - half_size_z + DASH_PATH_MARGIN_FROM_BOUNDS,
		"max_z": center.z + half_size_z - DASH_PATH_MARGIN_FROM_BOUNDS,
	}


func _clamp_point_to_bounds(point: Vector3, bounds: Dictionary) -> Vector3:
	var clamped := point
	clamped.x = clampf(clamped.x, float(bounds.get("min_x", clamped.x)), float(bounds.get("max_x", clamped.x)))
	clamped.z = clampf(clamped.z, float(bounds.get("min_z", clamped.z)), float(bounds.get("max_z", clamped.z)))
	clamped.y = DASH_PATH_SPAWN_Y
	return clamped


func _distance_point_to_segment_xz(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	var start := Vector2(segment_start.x, segment_start.z)
	var finish := Vector2(segment_end.x, segment_end.z)
	var target := Vector2(point.x, point.z)
	var segment := finish - start
	var segment_length_sq := segment.length_squared()
	if segment_length_sq <= 0.000001:
		return target.distance_to(start)
	var t := clampf((target - start).dot(segment) / segment_length_sq, 0.0, 1.0)
	var projection := start + (segment * t)
	return target.distance_to(projection)


func _segments_intersect_xz(a_start: Vector3, a_end: Vector3, b_start: Vector3, b_end: Vector3) -> bool:
	var p := Vector2(a_start.x, a_start.z)
	var p2 := Vector2(a_end.x, a_end.z)
	var q := Vector2(b_start.x, b_start.z)
	var q2 := Vector2(b_end.x, b_end.z)
	return Geometry2D.segment_intersects_segment(p, p2, q, q2) != null
