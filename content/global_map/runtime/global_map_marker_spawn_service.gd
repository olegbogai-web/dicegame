extends RefCounted
class_name GlobalMapMarkerSpawnService

const DEFAULT_WALL_MARGIN := 1.0
const DEFAULT_MIN_DISTANCE := 1.5
const DEFAULT_MAX_ATTEMPTS := 60
const GLOBAL_MAP_SPAWN_LOG_PREFIX := "[GlobalMapSpawn]"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func build_spawn_points(
	background_node: Node3D,
	origin_position: Vector3,
	marker_count: int,
	wall_margin: float = DEFAULT_WALL_MARGIN,
	min_distance: float = DEFAULT_MIN_DISTANCE,
	max_attempts: int = DEFAULT_MAX_ATTEMPTS
) -> Array[Vector3]:
	var spawned_points: Array[Vector3] = []
	if background_node == null or marker_count <= 0:
		return spawned_points

	var bounds := _resolve_background_bounds(background_node)
	if bounds.is_empty():
		print("%s skip: empty background bounds" % GLOBAL_MAP_SPAWN_LOG_PREFIX)
		return spawned_points

	var min_x: float = bounds["min_x"]
	var max_x: float = bounds["max_x"]
	var min_z: float = bounds["min_z"]
	var max_z: float = bounds["max_z"]
	var safe_min_x := min_x + wall_margin
	var safe_max_x := max_x - wall_margin
	var safe_min_z := min_z + wall_margin
	var safe_max_z := max_z - wall_margin
	if safe_min_x > safe_max_x or safe_min_z > safe_max_z:
		print("%s skip: invalid safe area x(%.2f..%.2f) z(%.2f..%.2f)" % [GLOBAL_MAP_SPAWN_LOG_PREFIX, safe_min_x, safe_max_x, safe_min_z, safe_max_z])
		return spawned_points

	for _index in marker_count:
		var candidate = _find_candidate_position(
			origin_position,
			spawned_points,
			safe_min_x,
			safe_max_x,
			safe_min_z,
			safe_max_z,
			min_distance,
			max_attempts
		)
		if candidate == null:
			print("%s marker[%d] not found" % [GLOBAL_MAP_SPAWN_LOG_PREFIX, _index])
			continue
		spawned_points.append(candidate as Vector3)
		print("%s marker[%d]=%s" % [GLOBAL_MAP_SPAWN_LOG_PREFIX, _index, candidate])

	return spawned_points


func _find_candidate_position(
	origin_position: Vector3,
	spawned_points: Array[Vector3],
	safe_min_x: float,
	safe_max_x: float,
	safe_min_z: float,
	safe_max_z: float,
	min_distance: float,
	max_attempts: int
) -> Variant:
	for _attempt in max_attempts:
		var x_delta := _rng.randf_range(2.0, 2.0)
		var candidate_x := origin_position.x + x_delta
		candidate_x = clampf(candidate_x, safe_min_x, safe_max_x)
		if candidate_x < origin_position.x:
			continue

		var z_delta := _rng.randf_range(-6.0, 6.0)
		var candidate_z := clampf(origin_position.z + z_delta, safe_min_z, safe_max_z)
		var candidate := Vector3(candidate_x, origin_position.y, candidate_z)
		if candidate.distance_to(origin_position) < min_distance:
			continue
		if _is_too_close_to_other_markers(candidate, spawned_points, min_distance):
			continue
		return candidate
	return null


func _is_too_close_to_other_markers(candidate: Vector3, spawned_points: Array[Vector3], min_distance: float) -> bool:
	for point in spawned_points:
		if candidate.distance_to(point) < min_distance:
			return true
	return false


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
