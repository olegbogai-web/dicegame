extends RefCounted
class_name GlobalMapPathPresenter

const DASH_Y := 0.005
const POSITION_JITTER := 0.1
const ROTATION_JITTER_DEGREES := 10.0
const PATH_WAVE_AMPLITUDE := 0.45
const PATH_CLEARANCE := 0.35
const PATH_SEGMENT_LENGTH := 0.9
const PATH_CANDIDATE_ATTEMPTS := 18

var _owner: Node3D
var _dash_template: MeshInstance3D
var _background: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _dynamic_dashes: Array[MeshInstance3D] = []
var _reserved_segments: Array[Dictionary] = []
var _background_bounds := {}


func _init() -> void:
	_rng.randomize()


func configure(owner: Node3D, dash_template: MeshInstance3D, background: MeshInstance3D) -> void:
	_owner = owner
	_dash_template = dash_template
	_background = background
	_background_bounds = _resolve_background_bounds(background)


func set_reserved_path(points: Array[Vector3]) -> void:
	_reserved_segments.clear()
	if points.size() < 2:
		return
	for index in range(points.size() - 1):
		_reserved_segments.append({
			"a": _to_xz(points[index]),
			"b": _to_xz(points[index + 1]),
		})


func clear_dynamic_paths() -> void:
	for dash in _dynamic_dashes:
		if dash != null and is_instance_valid(dash):
			dash.queue_free()
	_dynamic_dashes.clear()


func rebuild_paths(start_position: Vector3, marker_positions: Array[Vector3], blocked_positions: Array[Vector3] = []) -> void:
	clear_dynamic_paths()
	if _owner == null or _dash_template == null:
		return
	if _background_bounds.is_empty():
		return
	var occupied_points: Array[Vector2] = []
	for marker_position in marker_positions:
		occupied_points.append(_to_xz(marker_position))
	for blocked_position in blocked_positions:
		occupied_points.append(_to_xz(blocked_position))

	var path_segments: Array[Dictionary] = []
	for marker_position in marker_positions:
		var path_points := _build_path_points(start_position, marker_position, occupied_points, path_segments)
		if path_points.size() < 2:
			continue
		_spawn_dash_chain(path_points)
		for index in range(path_points.size() - 1):
			path_segments.append({
				"a": _to_xz(path_points[index]),
				"b": _to_xz(path_points[index + 1]),
			})


func _build_path_points(
	start_position: Vector3,
	target_position: Vector3,
	occupied_points: Array[Vector2],
	path_segments: Array[Dictionary]
) -> Array[Vector3]:
	var start := _to_xz(start_position)
	var target := _to_xz(target_position)
	var distance := start.distance_to(target)
	if distance <= PATH_SEGMENT_LENGTH:
		return [start_position, target_position]

	var direction := (target - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var point_count := maxi(2, int(ceil(distance / PATH_SEGMENT_LENGTH)))

	for _attempt in PATH_CANDIDATE_ATTEMPTS:
		var wave_phase := _rng.randf_range(-PI, PI)
		var amplitude := _rng.randf_range(PATH_WAVE_AMPLITUDE * 0.5, PATH_WAVE_AMPLITUDE)
		var path_points: Array[Vector3] = [Vector3(start.x, DASH_Y, start.y)]
		var is_valid := true
		for step in range(1, point_count):
			var t := float(step) / float(point_count)
			var base_point := start.lerp(target, t)
			var wave := sin((t * PI * 2.0) + wave_phase) * amplitude
			var jitter := Vector2(
				_rng.randf_range(-POSITION_JITTER, POSITION_JITTER),
				_rng.randf_range(-POSITION_JITTER, POSITION_JITTER)
			)
			var point_2d := base_point + perpendicular * wave + jitter
			if not _is_inside_bounds(point_2d):
				is_valid = false
				break
			if _is_too_close_to_markers(point_2d, occupied_points, target):
				is_valid = false
				break
			path_points.append(Vector3(point_2d.x, DASH_Y, point_2d.y))
		if not is_valid:
			continue
		path_points.append(Vector3(target.x, DASH_Y, target.y))
		if _intersects_existing_paths(path_points, path_segments):
			continue
		return path_points
	return []


func _spawn_dash_chain(path_points: Array[Vector3]) -> void:
	for index in range(path_points.size() - 1):
		var current_point := path_points[index]
		var next_point := path_points[index + 1]
		var direction := (next_point - current_point)
		direction.y = 0.0
		if direction.length_squared() <= 0.00001:
			continue
		var yaw := atan2(direction.z, direction.x)
		yaw += deg_to_rad(_rng.randf_range(-ROTATION_JITTER_DEGREES, ROTATION_JITTER_DEGREES))
		var position := current_point + Vector3(
			_rng.randf_range(-POSITION_JITTER, POSITION_JITTER),
			0.0,
			_rng.randf_range(-POSITION_JITTER, POSITION_JITTER)
		)
		position.y = DASH_Y
		if not _is_inside_bounds(_to_xz(position)):
			continue
		var dash_copy := _dash_template.duplicate() as MeshInstance3D
		if dash_copy == null:
			continue
		dash_copy.global_position = position
		dash_copy.rotation = Vector3(0.0, yaw, 0.0)
		dash_copy.scale = _dash_template.scale
		dash_copy.visible = true
		_owner.add_child(dash_copy)
		_dynamic_dashes.append(dash_copy)


func _intersects_existing_paths(path_points: Array[Vector3], path_segments: Array[Dictionary]) -> bool:
	for index in range(path_points.size() - 1):
		var a := _to_xz(path_points[index])
		var b := _to_xz(path_points[index + 1])
		for reserved_segment in _reserved_segments:
			if _segments_too_close(a, b, reserved_segment["a"], reserved_segment["b"]):
				return true
		for existing_segment in path_segments:
			if _segments_too_close(a, b, existing_segment["a"], existing_segment["b"]):
				return true
	return false


func _segments_too_close(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	if a1.distance_to(b1) <= PATH_CLEARANCE:
		return true
	if a1.distance_to(b2) <= PATH_CLEARANCE:
		return true
	if a2.distance_to(b1) <= PATH_CLEARANCE:
		return true
	if a2.distance_to(b2) <= PATH_CLEARANCE:
		return true
	if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
		return true
	if _point_to_segment_distance(a1, b1, b2) <= PATH_CLEARANCE:
		return true
	if _point_to_segment_distance(a2, b1, b2) <= PATH_CLEARANCE:
		return true
	if _point_to_segment_distance(b1, a1, a2) <= PATH_CLEARANCE:
		return true
	if _point_to_segment_distance(b2, a1, a2) <= PATH_CLEARANCE:
		return true
	return false


func _point_to_segment_distance(point: Vector2, segment_a: Vector2, segment_b: Vector2) -> float:
	var segment := segment_b - segment_a
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.000001:
		return point.distance_to(segment_a)
	var t := clampf((point - segment_a).dot(segment) / segment_length_squared, 0.0, 1.0)
	var projection := segment_a + segment * t
	return point.distance_to(projection)


func _is_too_close_to_markers(point: Vector2, marker_points: Array[Vector2], target: Vector2) -> bool:
	for marker_point in marker_points:
		if marker_point.distance_to(target) <= 0.001:
			continue
		if point.distance_to(marker_point) <= PATH_CLEARANCE:
			return true
	return false


func _to_xz(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


func _is_inside_bounds(point: Vector2) -> bool:
	if _background_bounds.is_empty():
		return false
	return point.x >= _background_bounds["min_x"] \
		and point.x <= _background_bounds["max_x"] \
		and point.y >= _background_bounds["min_z"] \
		and point.y <= _background_bounds["max_z"]


func _resolve_background_bounds(background_node: MeshInstance3D) -> Dictionary:
	if background_node == null or background_node.mesh == null:
		return {}
	var local_aabb := background_node.mesh.get_aabb()
	var half_size_x := local_aabb.size.x * 0.5 * absf(background_node.scale.x)
	var half_size_z := local_aabb.size.z * 0.5 * absf(background_node.scale.z)
	var center := background_node.global_position
	return {
		"min_x": center.x - half_size_x,
		"max_x": center.x + half_size_x,
		"min_z": center.z - half_size_z,
		"max_z": center.z + half_size_z,
	}
