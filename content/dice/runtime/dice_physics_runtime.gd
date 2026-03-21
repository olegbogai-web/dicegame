extends RefCounted
class_name DicePhysicsRuntime

const LINEAR_REST_THRESHOLD_SQUARED := 0.0004
const ANGULAR_REST_THRESHOLD_SQUARED := 0.0004

var _has_been_in_motion := false
var _is_locked_at_rest := false


func apply_defaults(
	dice: RigidBody3D,
	friction: float,
	bounce: float,
	linear_damp: float,
	angular_damp: float
) -> void:
	dice.linear_damp = linear_damp
	dice.angular_damp = angular_damp
	dice.can_sleep = true

	if dice.physics_material_override == null:
		dice.physics_material_override = PhysicsMaterial.new()

	dice.physics_material_override.friction = friction
	dice.physics_material_override.bounce = bounce


func physics_process(dice: RigidBody3D) -> void:
	if _is_locked_at_rest:
		return

	if dice.freeze:
		return

	if _is_moving(dice):
		_has_been_in_motion = true
		return

	if not _has_been_in_motion:
		return

	if dice.sleeping or _is_nearly_still(dice):
		_lock_at_rest(dice)


func refresh_collision_shape(
	dice: RigidBody3D,
	node_graph: DiceNodeGraph,
	definition: DiceDefinition,
	extra_size_multiplier: Vector3
) -> void:
	node_graph.ensure_nodes(dice, [])

	if definition == null:
		node_graph.collision_shape.shape = null
		return

	var box_shape := BoxShape3D.new()
	box_shape.size = definition.get_resolved_size() * extra_size_multiplier
	node_graph.collision_shape.shape = box_shape


func _is_moving(dice: RigidBody3D) -> bool:
	return dice.linear_velocity.length_squared() > LINEAR_REST_THRESHOLD_SQUARED \
		or dice.angular_velocity.length_squared() > ANGULAR_REST_THRESHOLD_SQUARED


func _is_nearly_still(dice: RigidBody3D) -> bool:
	return not _is_moving(dice)


func _lock_at_rest(dice: RigidBody3D) -> void:
	_is_locked_at_rest = true
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	dice.freeze = true
