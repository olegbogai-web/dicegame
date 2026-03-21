extends RefCounted
class_name DicePhysicsRuntime


func apply_defaults(
	dice: RigidBody3D,
	friction: float,
	bounce: float,
	linear_damp: float,
	angular_damp: float
) -> void:
	dice.linear_damp = linear_damp
	dice.angular_damp = angular_damp

	if dice.physics_material_override == null:
		dice.physics_material_override = PhysicsMaterial.new()

	dice.physics_material_override.friction = friction
	dice.physics_material_override.bounce = bounce


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
