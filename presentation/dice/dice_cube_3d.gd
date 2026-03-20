@tool
extends RigidBody3D
class_name DiceCube3D

signal definition_changed(definition: DiceDefinition)

const FACE_UP_DIRECTIONS := [
	Vector3(0.0, 0.0, 1.0),
	Vector3(0.0, 0.0, -1.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(0.0, -1.0, 0.0),
]

var _definition: DiceDefinition
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D

@export var definition: DiceDefinition:
	get:
		return _definition
	set(value):
		_definition = value
		_rebuild()
		emit_signal("definition_changed", _definition)

@export_range(0.5, 20.0, 0.1, "or_greater") var roll_impulse_strength: float = 4.0
@export_range(0.5, 40.0, 0.1, "or_greater") var roll_torque_strength: float = 12.0

func _ready() -> void:
	if _definition == null:
		_definition = DiceDefinition.new()
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree() and not Engine.is_editor_hint():
		return

	_ensure_core_nodes()
	_apply_physics_from_definition()
	_rebuild_mesh()
	_rebuild_faces()

func roll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	apply_central_impulse(Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(0.8, 1.6),
		rng.randf_range(-1.0, 1.0)
	) * roll_impulse_strength * mass)
	apply_torque_impulse(Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	) * roll_torque_strength * mass)

func apply_external_influence(impulse: Vector3, torque: Vector3 = Vector3.ZERO) -> void:
	apply_central_impulse(impulse)
	if torque != Vector3.ZERO:
		apply_torque_impulse(torque)

func get_top_face_index() -> int:
	var top_face_index := 0
	var best_alignment := -INF

	for face_index in FACE_UP_DIRECTIONS.size():
		var world_direction := global_transform.basis * FACE_UP_DIRECTIONS[face_index]
		var alignment := world_direction.normalized().dot(Vector3.UP)
		if alignment > best_alignment:
			best_alignment = alignment
			top_face_index = face_index

	return top_face_index

func get_top_face() -> DiceFaceData:
	if _definition == null:
		return null
	return _definition.get_face(get_top_face_index())

func _ensure_core_nodes() -> void:
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		add_child(_mesh_instance)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			_mesh_instance.owner = get_tree().edited_scene_root

	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "Collision"
		add_child(_collision_shape)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			_collision_shape.owner = get_tree().edited_scene_root

func _apply_physics_from_definition() -> void:
	if _definition == null:
		return

	mass = _definition.mass_value
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = _definition.bounce
	physics_material_override.friction = _definition.friction
	continuous_cd = true

func _rebuild_mesh() -> void:
	if _definition == null:
		return

	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3.ONE * _definition.cube_size
	_mesh_instance.mesh = cube_mesh

	var material := StandardMaterial3D.new()
	material.albedo_texture = _definition.base_texture
	material.metallic = 0.0
	material.roughness = 0.95
	_mesh_instance.material_override = material

	var box_shape := BoxShape3D.new()
	box_shape.size = cube_mesh.size
	_collision_shape.shape = box_shape

func _rebuild_faces() -> void:
	for child in get_children():
		if child is DiceFaceDisplay3D:
			child.queue_free()

	if _definition == null:
		return

	for face_index in _definition.faces.size():
		var face_display := DiceFaceDisplay3D.new()
		face_display.name = "Face_%s" % (face_index + 1)
		add_child(face_display)
		if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
			face_display.owner = get_tree().edited_scene_root
		face_display.configure(face_index, _definition.faces[face_index], _definition.cube_size)
