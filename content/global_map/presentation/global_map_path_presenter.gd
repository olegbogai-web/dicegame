extends RefCounted
class_name GlobalMapPathPresenter

const PATH_Y := 0.005
const POSITION_JITTER := 0.1
const ROTATION_JITTER_DEGREES := 10.0
const DASH_SPACING := 0.65
const MARKER_CLEARANCE := 0.7
const DEFAULT_ATTEMPTS_PER_PATH := 24

var _owner: Node3D
var _background: MeshInstance3D
var _dash_templates: Array[MeshInstance3D] = []
var _dynamic_dashes: Array[MeshInstance3D] = []
var _accepted_segments: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func configure(owner: Node3D, background: MeshInstance3D, dash_templates: Array[Node3D]) -> void:
	_owner = owner
	_background = background
	_dash_templates.clear()
	for template in dash_templates:
		if template == null or not template is MeshInstance3D:
			continue
		_dash_templates.append(template as MeshInstance3D)


func clear_dynamic_paths() -> void:
	for dash in _dynamic_dashes:
		if dash != null and is_instance_valid(dash):
			dash.queue_free()
	_dynamic_dashes.clear()
	_accepted_segments.clear()


func rebuild_paths(start_position: Vector3, target_positions: Array[Vector3], blocked_points: Array[Vector3]) -> void:
	clear_dynamic_paths()
	if _owner == null or _background == null or _dash_templates.is_empty() or target_positions.is_empty():
		return
	var bounds := _resolve_background_bounds()
	if bounds.is_empty():
		return

	for index in range(target_positions.size()):
		var target := target_positions[index]
		var path_points := _build_path_points(start_position, target, index, blocked_points, bounds)
		if path_points.is_empty():
			continue
		for segment_index in range(path_points.size() - 1):
			_accepted_segments.append({
				"from": path_points[segment_index],
				"to": path_points[segment_index + 1],
			})
		_spawn_dashes_for_path(path_points)


func _build_path_points(
	start_position: Vector3,
	target_position: Vector3,
	path_index: int,
	blocked_points: Array[Vector3],
	bounds: Dictionary
) -> Array[Vector3]:
	var start_xz := Vector2(start_position.x, start_position.z)
	var target_xz := Vector2(target_position.x, target_position.z)
	if start_xz.distance_to(target_xz) < DASH_SPACING:
		return []

	var direction := (target_xz - start_xz).normalized()
	if direction.length() <= 0.001:
		return []
	var normal := Vector2(-direction.y, direction.x)
	var travel_distance := start_xz.distance_to(target_xz)

	for _attempt in DEFAULT_ATTEMPTS_PER_PATH:
		var side_sign := 1.0 if (path_index % 2) == 0 else -1.0
		if _rng.randf() < 0.45:
			side_sign *= -1.0
		var amplitude := clampf(travel_distance * 0.16, 0.45, 1.1)
		amplitude += 0.12 * float(path_index)
		amplitude += _rng.randf_range(-0.1, 0.1)

		var first_anchor_xz := start_xz + direction * (travel_distance * 0.34) + normal * (amplitude * side_sign)
		var second_anchor_xz := start_xz + direction * (travel_distance * 0.68) - normal * (amplitude * side_sign * _rng.randf_range(0.55, 0.85))
		var points := [
			Vector3(start_xz.x, PATH_Y, start_xz.y),
			Vector3(first_anchor_xz.x, PATH_Y, first_anchor_xz.y),
			Vector3(second_anchor_xz.x, PATH_Y, second_anchor_xz.y),
			Vector3(target_xz.x, PATH_Y, target_xz.y),
		]

		if not _is_inside_bounds(points, bounds):
			continue
		if _segments_hit_blocked_points(points, blocked_points, target_position):
			continue
		if _segments_intersect_existing_paths(points):
			continue
		return points
	return []


func _spawn_dashes_for_path(path_points: Array[Vector3]) -> void:
	if path_points.size() < 2:
		return
	for segment_index in range(path_points.size() - 1):
		var from := path_points[segment_index]
		var to := path_points[segment_index + 1]
		var segment_length := from.distance_to(to)
		if segment_length <= 0.001:
			continue
		var pieces := max(1, int(floor(segment_length / DASH_SPACING)))
		for piece_index in range(pieces):
			var t := (float(piece_index) + 0.5) / float(pieces)
			var point := from.lerp(to, t)
			var look_target := to
			if piece_index < pieces - 1:
				look_target = from.lerp(to, (float(piece_index) + 1.0) / float(pieces))
			var dash := _create_dash_instance()
			if dash == null:
				continue
			_owner.add_child(dash)
			var jitter_x := _rng.randf_range(-POSITION_JITTER, POSITION_JITTER)
			var jitter_z := _rng.randf_range(-POSITION_JITTER, POSITION_JITTER)
			dash.global_position = Vector3(point.x + jitter_x, PATH_Y, point.z + jitter_z)
			var direction := Vector2(look_target.x - point.x, look_target.z - point.z)
			var angle := atan2(direction.x, direction.y)
			angle += deg_to_rad(_rng.randf_range(-ROTATION_JITTER_DEGREES, ROTATION_JITTER_DEGREES))
			dash.rotation = Vector3(0.0, angle, 0.0)
			_dynamic_dashes.append(dash)


func _create_dash_instance() -> MeshInstance3D:
	if _dash_templates.is_empty():
		return null
	var template := _dash_templates[_rng.randi_range(0, _dash_templates.size() - 1)]
	if template == null:
		return null
	var dash := MeshInstance3D.new()
	dash.mesh = template.mesh
	dash.material_override = template.material_override
	dash.cast_shadow = template.cast_shadow
	dash.layers = template.layers
	dash.scale = template.scale
	dash.visible = true
	return dash


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


func _is_inside_bounds(points: Array, bounds: Dictionary) -> bool:
	for point in points:
		if not point is Vector3:
			return false
		var value := point as Vector3
		if value.x < bounds["min_x"] or value.x > bounds["max_x"]:
			return false
		if value.z < bounds["min_z"] or value.z > bounds["max_z"]:
			return false
	return true


func _segments_hit_blocked_points(path_points: Array[Vector3], blocked_points: Array[Vector3], target_position: Vector3) -> bool:
	for segment_index in range(path_points.size() - 1):
		var from := Vector2(path_points[segment_index].x, path_points[segment_index].z)
		var to := Vector2(path_points[segment_index + 1].x, path_points[segment_index + 1].z)
		for blocked in blocked_points:
			if blocked.distance_to(target_position) < 0.05:
				continue
			var blocked_xz := Vector2(blocked.x, blocked.z)
			if _distance_point_to_segment(blocked_xz, from, to) < MARKER_CLEARANCE:
				return true
	return false


func _segments_intersect_existing_paths(path_points: Array[Vector3]) -> bool:
	for segment_index in range(path_points.size() - 1):
		var from := Vector2(path_points[segment_index].x, path_points[segment_index].z)
		var to := Vector2(path_points[segment_index + 1].x, path_points[segment_index + 1].z)
		for existing in _accepted_segments:
			var existing_from := existing.get("from", Vector3.ZERO) as Vector3
			var existing_to := existing.get("to", Vector3.ZERO) as Vector3
			var existing_from_xz := Vector2(existing_from.x, existing_from.z)
			var existing_to_xz := Vector2(existing_to.x, existing_to.z)
			if _segments_share_endpoint(from, to, existing_from_xz, existing_to_xz):
				continue
			if Geometry2D.segment_intersects_segment(from, to, existing_from_xz, existing_to_xz) != null:
				return true
	return false


func _segments_share_endpoint(a_from: Vector2, a_to: Vector2, b_from: Vector2, b_to: Vector2) -> bool:
	return a_from.distance_to(b_from) < 0.03 \
		or a_from.distance_to(b_to) < 0.03 \
		or a_to.distance_to(b_from) < 0.03 \
		or a_to.distance_to(b_to) < 0.03


func _distance_point_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var segment := to - from
	var segment_length_sq := segment.length_squared()
	if segment_length_sq <= 0.000001:
		return point.distance_to(from)
	var t := clampf((point - from).dot(segment) / segment_length_sq, 0.0, 1.0)
	var projection := from + segment * t
	return point.distance_to(projection)
