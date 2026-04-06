extends Node3D
class_name BoardController

const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const Dice = preload("res://content/dice/dice.gd")
const DUPLICATE_DICE_NAME := &"duplicate"

@export_category("Board References")
@export var floor_path: NodePath = ^"floor"
@export var default_dice_scene: PackedScene

@export_category("Spawn Bounds")
@export var spawn_bounds_margin: Vector2 = Vector2(0.15, 0.15)
@export var base_spawn_height: float = 0.5
@export var spawn_height_variation: float = 0.1
@export var spawn_spacing: float = 0.05
@export_range(1, 100, 1) var max_spawn_attempts: int = 24
@export var fallback_height_step: float = 0.3
@export var fallback_expand_step: Vector2 = Vector2(0.2, 0.2)

@export_category("Throw")
@export var throw_speed_min: float = 5
@export var throw_speed_max: float = 15
@export var throw_direction_spread: float = 1.25
@export var throw_vertical_velocity_min: float = 0.01
@export var throw_vertical_velocity_max: float = 0.4
@export var angular_velocity_min: Vector3 = Vector3(-35.0, -5.0, -35.0)
@export var angular_velocity_max: Vector3 = Vector3(35.0, 5.0, 35.0)
@export var use_continuous_collision_detection: bool = true

@onready var _floor: Node3D = get_node_or_null(floor_path)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func throw_dice(requests: Array[DiceThrowRequest]) -> Array[RigidBody3D]:
	var spawned_dice: Array[RigidBody3D] = []
	var occupied_areas: Array[AABB] = []
	var board_center := _get_board_center()
	var spawn_extents := _get_spawn_extents()
	var expanded_requests := _expand_duplicate_requests(requests)

	for request in expanded_requests:
		if request == null or request.dice_scene == null:
			push_warning("Skipped dice throw request because no scene was provided.")
			continue

		var instance := request.dice_scene.instantiate()
		if not instance is RigidBody3D:
			push_warning("Skipped dice throw request because the scene root is not a RigidBody3D.")
			if instance != null:
				instance.queue_free()
			continue

		var dice_body := instance as RigidBody3D
		if use_continuous_collision_detection:
			dice_body.continuous_cd = true

		if dice_body is Dice:
			var runtime_dice := dice_body as Dice
			runtime_dice.extra_size_multiplier = request.extra_size_multiplier
			var runtime_definition := request.metadata.get("definition") as DiceDefinition
			if runtime_definition != null:
				runtime_dice.definition = runtime_definition

		for metadata_key in request.metadata.keys():
			dice_body.set_meta(StringName(metadata_key), request.metadata[metadata_key])

		var resolved_size := _resolve_request_size(dice_body, request)
		var spawn_result := _find_spawn_transform(resolved_size, occupied_areas, board_center, spawn_extents)
		var spawn_basis := Basis.from_euler(Vector3(
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI)
		))
		dice_body.mass = max(request.mass, 0.001)

		add_child(dice_body)
		dice_body.global_transform = Transform3D(spawn_basis, spawn_result.origin)
		occupied_areas.append(_build_spawn_aabb(spawn_result.origin, resolved_size))

		var linear_velocity := _build_initial_velocity(spawn_result.origin, board_center)
		dice_body.linear_velocity = linear_velocity
		dice_body.angular_velocity = _random_vector3(angular_velocity_min, angular_velocity_max)
		if not spawn_result.found:
			push_warning("Fallback spawn was used for %s after exhausting spawn attempts." % dice_body.name)

		spawned_dice.append(dice_body)

	return spawned_dice


func _expand_duplicate_requests(requests: Array[DiceThrowRequest]) -> Array[DiceThrowRequest]:
	var expanded: Array[DiceThrowRequest] = []
	for request in requests:
		if request == null:
			continue
		expanded.append(request)
		if not _is_duplicate_dice_request(request):
			continue
		expanded.append(
			DiceThrowRequestScript.create(
				request.dice_scene,
				request.size,
				request.mass,
				request.extra_size_multiplier,
				request.metadata
			)
		)
	return expanded


func _is_duplicate_dice_request(request: DiceThrowRequest) -> bool:
	if request == null:
		return false
	var runtime_definition := request.metadata.get("definition") as DiceDefinition
	if runtime_definition == null:
		return false
	return StringName(runtime_definition.dice_name) == DUPLICATE_DICE_NAME


func throw_single_default_die() -> RigidBody3D:
	if default_dice_scene == null:
		push_warning("Default dice scene is not assigned.")
		return null

	var result := throw_dice([
		DiceThrowRequestScript.create(default_dice_scene)
	])
	return result[0] if not result.is_empty() else null


func _find_spawn_transform(
	resolved_size: Vector3,
	occupied_areas: Array[AABB],
	board_center: Vector3,
	spawn_extents: Vector2
) -> Dictionary:
	for attempt in max_spawn_attempts:
		var candidate_position := _random_spawn_position(resolved_size, board_center, spawn_extents)
		var candidate_aabb := _build_spawn_aabb(candidate_position, resolved_size)
		if not _intersects_spawned_dice(candidate_aabb, occupied_areas):
			return {
				"found": true,
				"origin": candidate_position,
			}

	var fallback_position := board_center + Vector3(
		_rng.randf_range(-fallback_expand_step.x, fallback_expand_step.x),
		base_spawn_height + spawn_height_variation + fallback_height_step * float(occupied_areas.size() + 1),
		_rng.randf_range(-fallback_expand_step.y, fallback_expand_step.y)
	)
	return {
		"found": false,
		"origin": fallback_position,
	}


func _random_spawn_position(resolved_size: Vector3, board_center: Vector3, spawn_extents: Vector2) -> Vector3:
	var allowed_x = max(spawn_extents.x - resolved_size.x * 0.5 - spawn_spacing, 0.0)
	var allowed_z = max(spawn_extents.y - resolved_size.z * 0.5 - spawn_spacing, 0.0)
	return Vector3(
		board_center.x + _rng.randf_range(-allowed_x, allowed_x),
		base_spawn_height + _rng.randf_range(0.0, spawn_height_variation),
		board_center.z + _rng.randf_range(-allowed_z, allowed_z)
	)


func get_random_floor_position() -> Vector3:
	var center := _get_board_center()
	var extents := _get_floor_extents()
	return Vector3(
		center.x + _rng.randf_range(-extents.x, extents.x),
		center.y,
		center.z + _rng.randf_range(-extents.y, extents.y)
	)


func is_position_over_floor(world_position: Vector3) -> bool:
	var center := _get_board_center()
	var extents := _get_floor_extents()
	return (
		absf(world_position.x - center.x) <= extents.x
		and absf(world_position.z - center.z) <= extents.y
	)


func _build_spawn_aabb(origin: Vector3, resolved_size: Vector3) -> AABB:
	var expanded_size := resolved_size + Vector3.ONE * spawn_spacing
	return AABB(origin - expanded_size * 0.5, expanded_size)


func _intersects_spawned_dice(candidate_aabb: AABB, occupied_areas: Array[AABB]) -> bool:
	for occupied_area in occupied_areas:
		if candidate_aabb.intersects(occupied_area):
			return true
	return false


func _build_initial_velocity(origin: Vector3, board_center: Vector3) -> Vector3:
	var to_center := board_center - origin
	var horizontal := Vector3(to_center.x, 0.0, to_center.z)
	if horizontal.length_squared() < 0.0001:
		horizontal = Vector3.FORWARD
	else:
		horizontal = horizontal.normalized()

	var spread := Vector3(
		_rng.randf_range(-throw_direction_spread, throw_direction_spread),
		0.0,
		_rng.randf_range(-throw_direction_spread, throw_direction_spread)
	)
	var direction := (horizontal + spread).normalized()
	var speed := _rng.randf_range(throw_speed_min, throw_speed_max)
	var vertical_velocity := _rng.randf_range(throw_vertical_velocity_min, throw_vertical_velocity_max)
	return direction * speed + Vector3.UP * vertical_velocity


func _resolve_request_size(dice_body: RigidBody3D, request: DiceThrowRequest) -> Vector3:
	if request.size != Vector3.ZERO:
		return request.size

	if dice_body is Dice and (dice_body as Dice).definition != null:
		var dice_definition := (dice_body as Dice).definition
		return dice_definition.get_resolved_size() * request.extra_size_multiplier

	for child in dice_body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return (child.shape as BoxShape3D).size

	return Vector3.ONE * 0.2


func _get_board_center() -> Vector3:
	return _floor.global_position if _floor != null else global_position


func _get_spawn_extents() -> Vector2:
	if _floor == null:
		return Vector2.ONE

	var collision := _floor.get_node_or_null(^"collision") as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		var half_size := (collision.shape as BoxShape3D).size * 0.5
		var basis := collision.global_transform.basis
		var extents := Vector2(
			absf(basis.x.x) * half_size.x + absf(basis.y.x) * half_size.y + absf(basis.z.x) * half_size.z,
			absf(basis.x.z) * half_size.x + absf(basis.y.z) * half_size.y + absf(basis.z.z) * half_size.z
		)
		return Vector2(
			max(extents.x - spawn_bounds_margin.x, 0.1),
			max(extents.y - spawn_bounds_margin.y, 0.1)
		)

	return Vector2.ONE


func _get_floor_extents() -> Vector2:
	if _floor == null:
		return Vector2.ONE

	var collision := _floor.get_node_or_null(^"collision") as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		var half_size := (collision.shape as BoxShape3D).size * 0.5
		var basis := collision.global_transform.basis
		return Vector2(
			absf(basis.x.x) * half_size.x + absf(basis.y.x) * half_size.y + absf(basis.z.x) * half_size.z,
			absf(basis.x.z) * half_size.x + absf(basis.y.z) * half_size.y + absf(basis.z.z) * half_size.z
		)

	return Vector2.ONE


func _random_vector3(min_value: Vector3, max_value: Vector3) -> Vector3:
	return Vector3(
		_rng.randf_range(min_value.x, max_value.x),
		_rng.randf_range(min_value.y, max_value.y),
		_rng.randf_range(min_value.z, max_value.z)
	)
