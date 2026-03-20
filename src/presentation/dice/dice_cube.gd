extends RigidBody3D
class_name DiceCube

const FACE_NORMALS := [
	Vector3.UP,
	Vector3.DOWN,
	Vector3.LEFT,
	Vector3.RIGHT,
	Vector3.BACK,
	Vector3.FORWARD,
]

const FACE_ROTATIONS := [
	Vector3(-PI * 0.5, 0.0, 0.0),
	Vector3(PI * 0.5, 0.0, 0.0),
	Vector3(0.0, -PI * 0.5, 0.0),
	Vector3(0.0, PI * 0.5, 0.0),
	Vector3(0.0, PI, 0.0),
	Vector3.ZERO,
]

var _definition: DiceDefinition
var _icon_library: DiceIconLibrary

@export var definition: DiceDefinition:
	get:
		return _definition
	set(value):
		_definition = value
		_rebuild()

@export var icon_library: DiceIconLibrary:
	get:
		return _icon_library
	set(value):
		_icon_library = value
		_rebuild_faces()

var _body_mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _faces_root: Node3D

func _ready() -> void:
	_ensure_nodes()
	_rebuild()

func roll(linear_impulse: Vector3 = Vector3(0, 6, 0), torque_impulse: Vector3 = Vector3(5, 7, 3)) -> void:
	apply_central_impulse(linear_impulse)
	apply_torque_impulse(torque_impulse)

func nudge(force: Vector3, position: Vector3 = Vector3.ZERO) -> void:
	apply_force(force, position)

func _ensure_nodes() -> void:
	if _body_mesh_instance == null:
		_body_mesh_instance = MeshInstance3D.new()
		_body_mesh_instance.name = "Body"
		add_child(_body_mesh_instance)

	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		add_child(_collision_shape)

	if _faces_root == null:
		_faces_root = Node3D.new()
		_faces_root.name = "Faces"
		add_child(_faces_root)

func _rebuild() -> void:
	if not is_node_ready():
		return

	_ensure_nodes()

	var dice_definition := _definition
	var dice_size := Vector3.ONE
	var base_texture: Texture2D = null

	if dice_definition != null:
		dice_size = dice_definition.size
		base_texture = dice_definition.base_texture

	var mesh := BoxMesh.new()
	mesh.size = dice_size
	_body_mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 1)
	material.roughness = 0.78
	material.metallic = 0.05
	material.albedo_texture = base_texture
	_body_mesh_instance.material_override = material

	var shape := BoxShape3D.new()
	shape.size = dice_size
	_collision_shape.shape = shape

	_rebuild_faces()

func _rebuild_faces() -> void:
	if not is_node_ready():
		return

	_ensure_nodes()

	for child in _faces_root.get_children():
		child.queue_free()

	var dice_definition := _definition
	if dice_definition == null:
		return

	var half_size := dice_definition.size * 0.5
	var overlay_fill := dice_definition.overlay_fill

	for face_index in FACE_NORMALS.size():
		var face_view := DiceFaceView.new()
		face_view.name = "Face_%s" % face_index
		face_view.definition = dice_definition.get_face_definition(face_index)
		face_view.icon_library = _icon_library
		face_view.size = _get_face_size(face_index, half_size, overlay_fill)
		face_view.transform = _get_face_transform(face_index, half_size)
		_faces_root.add_child(face_view)

func _get_face_size(face_index: int, half_size: Vector3, overlay_fill: float) -> Vector2:
	match face_index:
		0, 1:
			return Vector2(half_size.x * 2.0 * overlay_fill, half_size.z * 2.0 * overlay_fill)
		2, 3:
			return Vector2(half_size.z * 2.0 * overlay_fill, half_size.y * 2.0 * overlay_fill)
		_:
			return Vector2(half_size.x * 2.0 * overlay_fill, half_size.y * 2.0 * overlay_fill)

func _get_face_transform(face_index: int, half_size: Vector3) -> Transform3D:
	var normal: Vector3 = FACE_NORMALS[face_index]
	var offset := Vector3(
		normal.x * (half_size.x + 0.002),
		normal.y * (half_size.y + 0.002),
		normal.z * (half_size.z + 0.002)
	)
	var basis := Basis.from_euler(FACE_ROTATIONS[face_index])
	return Transform3D(basis, offset)
