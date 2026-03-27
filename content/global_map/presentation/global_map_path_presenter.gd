extends RefCounted
class_name GlobalMapPathPresenter

const DASH_Y := 0.005
const DASH_POSITION_JITTER := 0.1
const DASH_ROTATION_JITTER_DEGREES := 10.0
const MARKER_AVOID_RADIUS := 0.65
const PATH_SAMPLE_STEP := 0.42
const PATH_SAFE_MARGIN := 0.2
const MAX_CURVE_ATTEMPTS := 14

var _owner: Node3D
var _background: MeshInstance3D
var _dash_templates: Array[MeshInstance3D] = []
var _path_nodes: Array[MeshInstance3D] = []
var _occupied_segments: Array[Dictionary] = []
var _bounds := {}
var _rng := RandomNumberGenerator.new()
var _template_material: Material
var _template_mesh: Mesh
var _template_scale := Vector3.ONE


func _init() -> void:
	_rng.randomize()


func configure(owner: Node3D, background: MeshInstance3D, dash_templates: Array[Node3D]) -> void:
	_owner = owner
	_background = background
	_dash_templates.clear()
	for template_node in dash_templates:
		if template_node is MeshInstance3D:
			_dash_templates.append(template_node as MeshInstance3D)
	if _dash_templates.is_empty():
		return
	var source_template := _dash_templates[0]
	_template_material = source_template.material_override
	_template_mesh = source_template.mesh
	_template_scale = source_template.scale
	for template in _dash_templates:
		template.visible = false
	_bounds = _resolve_background_bounds(background)


func clear_paths() -> void:
	for node in _path_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_path_nodes.clear()
	_occupied_segments.clear()


func build_paths(origin: Vector3, marker_positions: Array[Vector3]) -> void:
	clear_paths()
	if _owner == null or _template_mesh == null:
		return
	if marker_positions.is_empty():
		return

	var sorted_targets := marker_positions.duplicate()
	sorted_targets.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.z < b.z
	)

	for target in sorted_targets:
		var points := _build_single_path(origin, target, marker_positions)
		if points.size() < 2:
			continue
		_spawn_path_dashes(points)
		_register_segments(points)


func _build_single_path(origin: Vector3, target: Vector3, all_markers: Array[Vector3]) -> Array[Vector3]:
	var direct_distance := origin.distance_to(target)
	if direct_distance <= 0.001:
		return []
	var direction := (target - origin).normalized()
	var normal := Vector3(-direction.z, 0.0, direction.x)
	if normal.length_squared() <= 0.0001:
		normal = Vector3(0.0, 0.0, 1.0)
	var base_offset := clampf(direct_distance * 0.22, 0.28, 0.95)
	var tries: Array[float] = [
		base_offset,
		-base_offset,
		base_offset * 1.45,
		-base_offset * 1.45,
		base_offset * 0.65,
		-base_offset * 0.65,
		0.0
	]

	for curve_offset in tries:
		var control := origin.lerp(target, 0.5) + normal * curve_offset
		var sampled := _sample_curve(origin, control, target)
		if _is_path_valid(sampled, all_markers):
			return sampled

	for _attempt in MAX_CURVE_ATTEMPTS:
		var random_offset := _rng.randf_range(-base_offset * 1.8, base_offset * 1.8)
		var random_control := origin.lerp(target, 0.5) + normal * random_offset
		var random_sampled := _sample_curve(origin, random_control, target)
		if _is_path_valid(random_sampled, all_markers):
			return random_sampled
	return []


func _sample_curve(start: Vector3, control: Vector3, target: Vector3) -> Array[Vector3]:
	var sampled: Array[Vector3] = []
	var distance := start.distance_to(target)
	var segments := max(2, int(ceil(distance / PATH_SAMPLE_STEP)))
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var point := _bezier_quadratic(start, control, target, t)
		point.y = DASH_Y
		if sampled.is_empty() or sampled[sampled.size() - 1].distance_to(point) >= PATH_SAMPLE_STEP * 0.8 or index == segments:
			sampled.append(point)
	return sampled


func _bezier_quadratic(start: Vector3, control: Vector3, target: Vector3, t: float) -> Vector3:
	var inv_t := 1.0 - t
	return (inv_t * inv_t * start) + (2.0 * inv_t * t * control) + (t * t * target)


func _is_path_valid(points: Array[Vector3], all_markers: Array[Vector3]) -> bool:
	if points.size() < 2:
		return false
	for point in points:
		if not _is_point_inside_bounds(point):
			return false
	for index in range(points.size() - 1):
		var from_point := points[index]
		var to_point := points[index + 1]
		if _intersects_existing_paths(from_point, to_point):
			return false
		if _segment_intersects_markers(from_point, to_point, all_markers):
			return false
	return true


func _spawn_path_dashes(points: Array[Vector3]) -> void:
	for index in range(points.size() - 1):
		var current := points[index]
		var next := points[index + 1]
		var direction := (next - current).normalized()
		if direction.length_squared() <= 0.0001:
			continue
		var dash := MeshInstance3D.new()
		dash.mesh = _template_mesh
		dash.material_override = _template_material
		dash.scale = _template_scale
		var jittered_position := current + Vector3(
			_rng.randf_range(-DASH_POSITION_JITTER, DASH_POSITION_JITTER),
			0.0,
			_rng.randf_range(-DASH_POSITION_JITTER, DASH_POSITION_JITTER)
		)
		jittered_position.y = DASH_Y
		dash.global_position = jittered_position
		var base_rotation := atan2(direction.z, direction.x)
		var jittered_rotation := base_rotation + deg_to_rad(_rng.randf_range(-DASH_ROTATION_JITTER_DEGREES, DASH_ROTATION_JITTER_DEGREES))
		dash.rotation = Vector3(0.0, jittered_rotation, 0.0)
		_owner.add_child(dash)
		_path_nodes.append(dash)


func _register_segments(points: Array[Vector3]) -> void:
	for index in range(points.size() - 1):
		_occupied_segments.append({
			"a": points[index],
			"b": points[index + 1],
		})


func _intersects_existing_paths(a: Vector3, b: Vector3) -> bool:
	for segment in _occupied_segments:
		var other_a := segment.get("a", Vector3.ZERO) as Vector3
		var other_b := segment.get("b", Vector3.ZERO) as Vector3
		if a.distance_to(other_a) < 0.05 or a.distance_to(other_b) < 0.05 or b.distance_to(other_a) < 0.05 or b.distance_to(other_b) < 0.05:
			continue
		if _segments_intersect_2d(a, b, other_a, other_b):
			return true
	return false


func _segment_intersects_markers(a: Vector3, b: Vector3, markers: Array[Vector3]) -> bool:
	for marker in markers:
		if marker.distance_to(a) <= 0.05 or marker.distance_to(b) <= 0.05:
			continue
		if _distance_point_to_segment_2d(marker, a, b) < MARKER_AVOID_RADIUS:
			return true
	return false


func _segments_intersect_2d(a1: Vector3, a2: Vector3, b1: Vector3, b2: Vector3) -> bool:
	var p := Vector2(a1.x, a1.z)
	var p2 := Vector2(a2.x, a2.z)
	var q := Vector2(b1.x, b1.z)
	var q2 := Vector2(b2.x, b2.z)
	return Geometry2D.segment_intersects_segment(p, p2, q, q2) != null


func _distance_point_to_segment_2d(point: Vector3, segment_a: Vector3, segment_b: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var a := Vector2(segment_a.x, segment_a.z)
	var b := Vector2(segment_b.x, segment_b.z)
	var ab := b - a
	var ab_length_squared := ab.length_squared()
	if ab_length_squared <= 0.000001:
		return p.distance_to(a)
	var projection := clampf((p - a).dot(ab) / ab_length_squared, 0.0, 1.0)
	var closest := a + ab * projection
	return p.distance_to(closest)


func _is_point_inside_bounds(point: Vector3) -> bool:
	if _bounds.is_empty():
		return true
	var min_x: float = _bounds["min_x"] + PATH_SAFE_MARGIN
	var max_x: float = _bounds["max_x"] - PATH_SAFE_MARGIN
	var min_z: float = _bounds["min_z"] + PATH_SAFE_MARGIN
	var max_z: float = _bounds["max_z"] - PATH_SAFE_MARGIN
	return point.x >= min_x and point.x <= max_x and point.z >= min_z and point.z <= max_z


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
