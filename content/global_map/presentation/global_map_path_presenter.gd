extends RefCounted
class_name GlobalMapPathPresenter

const DASH_Y := 0.005
const DASH_SPACING := 1.0
const DASH_POSITION_JITTER := 0.1
const DASH_ROTATION_JITTER_DEG := 10.0
const MARKER_CLEARANCE_RADIUS := 0.9
const PATH_SAMPLES := 18
const MAX_PATH_BUILD_ATTEMPTS := 24

var _owner: Node3D
var _background: MeshInstance3D
var _dash_template: MeshInstance3D
var _dash_nodes: Array[MeshInstance3D] = []
var _path_segments: Array[PackedVector2Array] = []
var _bounds := {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func configure(owner: Node3D, background: MeshInstance3D, dash_template: MeshInstance3D) -> void:
	_owner = owner
	_background = background
	_dash_template = dash_template
	_bounds = _resolve_background_bounds()


func clear_dynamic_paths() -> void:
	for node in _dash_nodes:
		if node == null or not is_instance_valid(node):
			continue
		node.queue_free()
	_dash_nodes.clear()
	_path_segments.clear()


func show_paths(start_position: Vector3, target_positions: Array[Vector3], blocked_markers: Array[Vector3]) -> void:
	clear_dynamic_paths()
	if _owner == null or _dash_template == null or _background == null:
		return
	if target_positions.is_empty():
		return

	var sorted_targets := target_positions.duplicate()
	sorted_targets.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.z < b.z
	)

	for target_index in range(sorted_targets.size()):
		var target := sorted_targets[target_index]
		var path_points := _build_non_intersecting_path(start_position, target, blocked_markers, target_index)
		if path_points.is_empty():
			continue
		_path_segments.append(_build_segments(path_points))
		_spawn_dashes_for_path(path_points)


func _build_non_intersecting_path(
	start_position: Vector3,
	target_position: Vector3,
	blocked_markers: Array[Vector3],
	path_index: int
) -> Array[Vector3]:
	for _attempt in MAX_PATH_BUILD_ATTEMPTS:
		var candidate := _build_wavy_path(start_position, target_position, path_index)
		if candidate.is_empty():
			continue
		if _path_goes_outside_bounds(candidate):
			continue
		if _path_hits_other_markers(candidate, blocked_markers, target_position):
			continue
		if _path_intersects_existing_paths(candidate):
			continue
		return candidate
	return []


func _build_wavy_path(start_position: Vector3, target_position: Vector3, path_index: int) -> Array[Vector3]:
	var direction := (target_position - start_position)
	direction.y = 0.0
	var length := direction.length()
	if length <= 0.01:
		return []
	direction = direction / length
	var perpendicular := Vector3(-direction.z, 0.0, direction.x)
	var lane_offset := (float(path_index) - 1.0) * 0.35
	var wave_amplitude := lane_offset + _rng.randf_range(-0.25, 0.25)

	var points: Array[Vector3] = []
	for sample in range(PATH_SAMPLES + 1):
		var t := float(sample) / float(PATH_SAMPLES)
		var base := start_position.lerp(target_position, t)
		var waviness := sin(t * PI) * wave_amplitude
		var local_jitter := _rng.randf_range(-0.04, 0.04)
		var point := base + perpendicular * (waviness + local_jitter)
		point.y = DASH_Y
		points.append(point)
	return points


func _spawn_dashes_for_path(path_points: Array[Vector3]) -> void:
	var path_length := _polyline_length(path_points)
	if path_length <= 0.01:
		return
	var travelled := DASH_SPACING
	while travelled < path_length:
		var sample := _sample_polyline(path_points, travelled)
		var look_ahead := _sample_polyline(path_points, min(travelled + 0.15, path_length))
		var dash := _create_dash_instance()
		if dash == null:
			return
		var jitter := Vector3(
			_rng.randf_range(-DASH_POSITION_JITTER, DASH_POSITION_JITTER),
			0.0,
			_rng.randf_range(-DASH_POSITION_JITTER, DASH_POSITION_JITTER)
		)
		dash.global_position = Vector3(sample.x, DASH_Y, sample.z) + jitter
		_align_dash(dash, sample, look_ahead)
		_owner.add_child(dash)
		_dash_nodes.append(dash)
		travelled += DASH_SPACING


func _align_dash(dash: MeshInstance3D, from_point: Vector3, to_point: Vector3) -> void:
	var direction := to_point - from_point
	direction.y = 0.0
	if direction.length() <= 0.0001:
		return
	var yaw := atan2(direction.x, direction.z)
	dash.rotation = Vector3(
		_dash_template.rotation.x,
		yaw + deg_to_rad(90.0) + deg_to_rad(_rng.randf_range(-DASH_ROTATION_JITTER_DEG, DASH_ROTATION_JITTER_DEG)),
		_dash_template.rotation.z
	)


func _create_dash_instance() -> MeshInstance3D:
	if _dash_template == null:
		return null
	var dash := MeshInstance3D.new()
	dash.mesh = _dash_template.mesh
	dash.scale = _dash_template.scale
	dash.visible = true
	if _dash_template.material_override != null:
		dash.material_override = _dash_template.material_override.duplicate()
	return dash


func _polyline_length(path_points: Array[Vector3]) -> float:
	var length := 0.0
	for index in range(path_points.size() - 1):
		length += path_points[index].distance_to(path_points[index + 1])
	return length


func _sample_polyline(path_points: Array[Vector3], distance_along: float) -> Vector3:
	if path_points.is_empty():
		return Vector3.ZERO
	if distance_along <= 0.0:
		return path_points[0]
	var traversed := 0.0
	for index in range(path_points.size() - 1):
		var from_point := path_points[index]
		var to_point := path_points[index + 1]
		var segment_length := from_point.distance_to(to_point)
		if traversed + segment_length >= distance_along:
			var local_t := (distance_along - traversed) / max(segment_length, 0.0001)
			return from_point.lerp(to_point, local_t)
		traversed += segment_length
	return path_points[path_points.size() - 1]


func _path_goes_outside_bounds(points: Array[Vector3]) -> bool:
	if _bounds.is_empty():
		return false
	var min_x: float = _bounds["min_x"]
	var max_x: float = _bounds["max_x"]
	var min_z: float = _bounds["min_z"]
	var max_z: float = _bounds["max_z"]
	for point in points:
		if point.x < min_x or point.x > max_x:
			return true
		if point.z < min_z or point.z > max_z:
			return true
	return false


func _path_hits_other_markers(points: Array[Vector3], blocked_markers: Array[Vector3], target: Vector3) -> bool:
	for point in points:
		for marker_position in blocked_markers:
			if marker_position.distance_to(target) < 0.001:
				continue
			var marker_on_ground := Vector3(marker_position.x, DASH_Y, marker_position.z)
			if point.distance_to(marker_on_ground) < MARKER_CLEARANCE_RADIUS:
				return true
	return false


func _path_intersects_existing_paths(points: Array[Vector3]) -> bool:
	var candidate_segments := _build_segments(points)
	for candidate_index in range(0, candidate_segments.size(), 2):
		var candidate_start := candidate_segments[candidate_index]
		var candidate_end := candidate_segments[candidate_index + 1]
		for existing_segments in _path_segments:
			for existing_index in range(0, existing_segments.size(), 2):
				var existing_start := existing_segments[existing_index]
				var existing_end := existing_segments[existing_index + 1]
				if _segments_intersect(candidate_start, candidate_end, existing_start, existing_end):
					return true
	return false


func _build_segments(points: Array[Vector3]) -> PackedVector2Array:
	var segments := PackedVector2Array()
	for index in range(points.size() - 1):
		var from_point := points[index]
		var to_point := points[index + 1]
		segments.append(Vector2(from_point.x, from_point.z))
		segments.append(Vector2(to_point.x, to_point.z))
	return segments


func _segments_intersect(a_start: Vector2, a_end: Vector2, b_start: Vector2, b_end: Vector2) -> bool:
	if a_start.distance_to(b_start) < 0.1:
		return false
	if a_start.distance_to(b_end) < 0.1:
		return false
	if a_end.distance_to(b_start) < 0.1:
		return false
	if a_end.distance_to(b_end) < 0.1:
		return false
	var d1 := _cross_2d(a_end - a_start, b_start - a_start)
	var d2 := _cross_2d(a_end - a_start, b_end - a_start)
	var d3 := _cross_2d(b_end - b_start, a_start - b_start)
	var d4 := _cross_2d(b_end - b_start, a_end - b_start)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


func _cross_2d(lhs: Vector2, rhs: Vector2) -> float:
	return lhs.x * rhs.y - lhs.y * rhs.x


func _resolve_background_bounds() -> Dictionary:
	if _background == null or _background.mesh == null:
		return {}
	var local_aabb := _background.mesh.get_aabb()
	var half_size_x := local_aabb.size.x * 0.5 * absf(_background.scale.x)
	var half_size_z := local_aabb.size.z * 0.5 * absf(_background.scale.z)
	var center := _background.global_position
	return {
		"min_x": center.x - half_size_x,
		"max_x": center.x + half_size_x,
		"min_z": center.z - half_size_z,
		"max_z": center.z + half_size_z,
	}
