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
const DYNAMIC_PATH_DASH_HEIGHT := 0.005
const DYNAMIC_PATH_DASH_STEP := 0.62
const DYNAMIC_PATH_MARGIN := 0.35
const DYNAMIC_PATH_LANE_SPACING := 0.8
const DYNAMIC_PATH_MARKER_CLEARANCE := 0.85
const DASH_SWAY_ROTATION_DEGREES := 10.0
const DASH_SWAY_POSITION_AMPLITUDE := 0.1
const DASH_SWAY_SPEED := 2.4
const PATH_BUILD_ATTEMPTS := 8

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
var _dynamic_dash_nodes: Array[MeshInstance3D] = []
var _dynamic_dash_base_positions: Array[Vector3] = []
var _dynamic_dash_base_rotations_y: Array[float] = []
var _dynamic_paths_segments: Array[PackedVector2Array] = []
var _path_anchor_position := Vector3.ZERO
var _path_rng := RandomNumberGenerator.new()
var _dash_sway_time := 0.0


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
	_resolve_path_anchor_position()
	_path_rng.randomize()
	_restore_persisted_state()
	_schedule_global_map_dice_roll_if_needed()


func process(delta: float) -> void:
	_dash_sway_time += delta
	_animate_dynamic_dashes()
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
		_rebuild_paths_to_markers(marker_specs)
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
	_rebuild_paths_to_markers(marker_specs)


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


func _resolve_path_anchor_position() -> void:
	if _road_nodes.is_empty():
		_path_anchor_position = _hero_movement.get_ground_position()
		return
	var last_road_node := _road_nodes[_road_nodes.size() - 1]
	if last_road_node == null:
		_path_anchor_position = _hero_movement.get_ground_position()
		return
	_path_anchor_position = last_road_node.global_position
	_path_anchor_position.y = DYNAMIC_PATH_DASH_HEIGHT


func _rebuild_paths_to_markers(marker_specs: Array[Dictionary]) -> void:
	_clear_dynamic_paths()
	var marker_positions: Array[Vector3] = []
	for marker_spec in marker_specs:
		if not bool(marker_spec.get("visible", true)):
			continue
		var marker_position = marker_spec.get("position", null)
		if marker_position is Vector3:
			var point := marker_position as Vector3
			point.y = DYNAMIC_PATH_DASH_HEIGHT
			marker_positions.append(point)
	if marker_positions.is_empty():
		return
	var bounds := _resolve_background_bounds()
	if bounds.is_empty():
		return
	marker_positions.sort_custom(func(a: Vector3, b: Vector3): return a.z < b.z)
	var path_count := marker_positions.size()
	for index in range(path_count):
		var target := marker_positions[index]
		var lane_index := float(index) - (float(path_count - 1) * 0.5)
		var lane_offset := lane_index * DYNAMIC_PATH_LANE_SPACING
		var path := _build_path_candidate(target, lane_offset, index, marker_positions, bounds)
		if path.size() < 2:
			continue
		_dynamic_paths_segments.append(path)
		_spawn_path_dashes(path)


func _build_path_candidate(
	target: Vector3,
	lane_offset: float,
	path_index: int,
	all_markers: Array[Vector3],
	bounds: Dictionary
) -> PackedVector2Array:
	for _attempt in PATH_BUILD_ATTEMPTS:
		var jitter := _path_rng.randf_range(-0.35, 0.35)
		var points: Array[Vector3] = []
		var middle_x := lerpf(_path_anchor_position.x, target.x, 0.5)
		points.append(_path_anchor_position)
		points.append(Vector3(_path_anchor_position.x + 0.9, DYNAMIC_PATH_DASH_HEIGHT, _path_anchor_position.z + lane_offset))
		points.append(Vector3(middle_x, DYNAMIC_PATH_DASH_HEIGHT, lerpf(_path_anchor_position.z, target.z, 0.5) + (lane_offset * 0.45) + jitter))
		points.append(Vector3(target.x - 0.85, DYNAMIC_PATH_DASH_HEIGHT, target.z + (lane_offset * 0.2)))
		points.append(target)

		var sampled_path := _sample_wavy_path(points, path_index, bounds)
		if sampled_path.size() < 2:
			continue
		if _path_collides_with_paths(sampled_path):
			continue
		if _path_touches_other_markers(sampled_path, target, all_markers):
			continue
		return sampled_path
	return PackedVector2Array()


func _sample_wavy_path(points: Array[Vector3], path_index: int, bounds: Dictionary) -> PackedVector2Array:
	var sampled := PackedVector2Array()
	for segment_index in range(points.size() - 1):
		var start := points[segment_index]
		var finish := points[segment_index + 1]
		var segment_length := start.distance_to(finish)
		if segment_length <= 0.01:
			continue
		var divisions := max(2, int(ceil(segment_length / 0.35)))
		for sample_index in range(divisions + 1):
			if segment_index > 0 and sample_index == 0:
				continue
			var t := float(sample_index) / float(divisions)
			var point := start.lerp(finish, t)
			if segment_index > 0 and segment_index < points.size() - 2:
				var sway := sin((t * PI * 2.0) + float(path_index)) * 0.2
				point.z += sway
			var clamped := _clamp_path_point(point, bounds)
			sampled.append(Vector2(clamped.x, clamped.z))
	return sampled


func _spawn_path_dashes(path: PackedVector2Array) -> void:
	if _road_nodes.is_empty():
		return
	var dash_template := _road_nodes[0] as MeshInstance3D
	if dash_template == null:
		return
	for segment_index in range(path.size() - 1):
		var start := Vector3(path[segment_index].x, DYNAMIC_PATH_DASH_HEIGHT, path[segment_index].y)
		var finish := Vector3(path[segment_index + 1].x, DYNAMIC_PATH_DASH_HEIGHT, path[segment_index + 1].y)
		var segment_length := start.distance_to(finish)
		if segment_length < 0.1:
			continue
		var direction := (finish - start).normalized()
		var dash_count := max(1, int(floor(segment_length / DYNAMIC_PATH_DASH_STEP)))
		for dash_index in range(dash_count):
			var t := (float(dash_index) + 0.5) / float(dash_count)
			var dash_position := start.lerp(finish, t)
			var dash_node := MeshInstance3D.new()
			dash_node.mesh = dash_template.mesh
			dash_node.material_override = dash_template.material_override
			dash_node.scale = dash_template.scale
			dash_node.position = dash_position
			dash_node.rotation.y = atan2(direction.x, direction.z)
			_owner.add_child(dash_node)
			_dynamic_dash_nodes.append(dash_node)
			_dynamic_dash_base_positions.append(dash_position)
			_dynamic_dash_base_rotations_y.append(dash_node.rotation.y)


func _animate_dynamic_dashes() -> void:
	for index in range(_dynamic_dash_nodes.size()):
		var dash_node := _dynamic_dash_nodes[index]
		if dash_node == null or not is_instance_valid(dash_node):
			continue
		var base_position := _dynamic_dash_base_positions[index]
		var base_rotation_y := _dynamic_dash_base_rotations_y[index]
		var phase := _dash_sway_time * DASH_SWAY_SPEED + (float(index) * 0.4)
		var offset := Vector3(
			sin(phase) * DASH_SWAY_POSITION_AMPLITUDE,
			0.0,
			cos(phase) * DASH_SWAY_POSITION_AMPLITUDE
		)
		dash_node.position = base_position + offset
		dash_node.rotation.y = base_rotation_y + deg_to_rad(DASH_SWAY_ROTATION_DEGREES) * sin(phase)


func _clear_dynamic_paths() -> void:
	for dash_node in _dynamic_dash_nodes:
		if dash_node != null and is_instance_valid(dash_node):
			dash_node.queue_free()
	_dynamic_dash_nodes.clear()
	_dynamic_dash_base_positions.clear()
	_dynamic_dash_base_rotations_y.clear()
	_dynamic_paths_segments.clear()


func _path_collides_with_paths(path: PackedVector2Array) -> bool:
	for segment_index in range(path.size() - 1):
		var segment_start := path[segment_index]
		var segment_end := path[segment_index + 1]
		for existing_path in _dynamic_paths_segments:
			for existing_index in range(existing_path.size() - 1):
				var existing_start := existing_path[existing_index]
				var existing_end := existing_path[existing_index + 1]
				if _segments_share_endpoint(segment_start, segment_end, existing_start, existing_end):
					continue
				if Geometry2D.segment_intersects_segment(segment_start, segment_end, existing_start, existing_end) != null:
					return true
	return false


func _segments_share_endpoint(a_start: Vector2, a_end: Vector2, b_start: Vector2, b_end: Vector2) -> bool:
	const ENDPOINT_EPSILON := 0.001
	return (
		a_start.distance_to(b_start) <= ENDPOINT_EPSILON
		or a_start.distance_to(b_end) <= ENDPOINT_EPSILON
		or a_end.distance_to(b_start) <= ENDPOINT_EPSILON
		or a_end.distance_to(b_end) <= ENDPOINT_EPSILON
	)


func _path_touches_other_markers(path: PackedVector2Array, own_target: Vector3, markers: Array[Vector3]) -> bool:
	for point in path:
		var world_point := Vector3(point.x, DYNAMIC_PATH_DASH_HEIGHT, point.y)
		for marker in markers:
			if marker.distance_to(own_target) <= 0.01:
				continue
			if world_point.distance_to(marker) < DYNAMIC_PATH_MARKER_CLEARANCE:
				return true
	return false


func _clamp_path_point(point: Vector3, bounds: Dictionary) -> Vector3:
	return Vector3(
		clampf(point.x, bounds["min_x"] + DYNAMIC_PATH_MARGIN, bounds["max_x"] - DYNAMIC_PATH_MARGIN),
		DYNAMIC_PATH_DASH_HEIGHT,
		clampf(point.z, bounds["min_z"] + DYNAMIC_PATH_MARGIN, bounds["max_z"] - DYNAMIC_PATH_MARGIN)
	)


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
		"min_x": center.x - half_size_x,
		"max_x": center.x + half_size_x,
		"min_z": center.z - half_size_z,
		"max_z": center.z + half_size_z,
	}
