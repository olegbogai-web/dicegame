@tool
class_name DiceView
extends RigidBody3D

const FACE_TRANSFORMS := {
	0: {"name": "Top", "position": Vector3.UP, "rotation": Vector3(-PI * 0.5, 0, 0)},
	1: {"name": "Bottom", "position": Vector3.DOWN, "rotation": Vector3(PI * 0.5, 0, 0)},
	2: {"name": "Front", "position": Vector3.FORWARD, "rotation": Vector3.ZERO},
	3: {"name": "Back", "position": Vector3.BACK, "rotation": Vector3(0, PI, 0)},
	4: {"name": "Right", "position": Vector3.RIGHT, "rotation": Vector3(0, PI * 0.5, 0)},
	5: {"name": "Left", "position": Vector3.LEFT, "rotation": Vector3(0, -PI * 0.5, 0)}
}

@export var definition: DiceDefinition : set = set_definition, get = get_definition

var _definition: DiceDefinition
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _faces_root: Node3D

func _ready() -> void:
	ensure_structure()
	rebuild()

func set_definition(value: DiceDefinition) -> void:
	_definition = value
	if is_node_ready():
		rebuild.call_deferred()

func get_definition() -> DiceDefinition:
	return _definition

func ensure_structure() -> void:
	if _mesh_instance == null:
		_mesh_instance = get_node_or_null("Body") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Body"
		add_child(_mesh_instance)
		_mesh_instance.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		add_child(_collision_shape)
		_collision_shape.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	if _faces_root == null:
		_faces_root = get_node_or_null("Faces") as Node3D
	if _faces_root == null:
		_faces_root = Node3D.new()
		_faces_root.name = "Faces"
		add_child(_faces_root)
		_faces_root.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

func rebuild() -> void:
	ensure_structure()
	var data := _definition
	if data == null:
		return

	var scaled_size := data.get_scaled_size()
	_build_body(data, scaled_size)
	_build_faces(data, scaled_size)

func _build_body(data: DiceDefinition, scaled_size: Vector3) -> void:
	var box_mesh := BoxMesh.new()
	box_mesh.size = scaled_size
	_mesh_instance.mesh = box_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = data.cube_color
	material.roughness = 0.95
	material.metallic = 0.02
	if data.surface_texture != null:
		material.albedo_texture = data.surface_texture
	_mesh_instance.material_override = material

	var shape := BoxShape3D.new()
	shape.size = scaled_size
	_collision_shape.shape = shape

func _build_faces(data: DiceDefinition, scaled_size: Vector3) -> void:
	for child in _faces_root.get_children():
		child.free()

	var face_depths := {
		0: scaled_size.y * 0.5 + data.face_padding,
		1: scaled_size.y * 0.5 + data.face_padding,
		2: scaled_size.z * 0.5 + data.face_padding,
		3: scaled_size.z * 0.5 + data.face_padding,
		4: scaled_size.x * 0.5 + data.face_padding,
		5: scaled_size.x * 0.5 + data.face_padding
	}
	var face_sizes := {
		0: Vector2(scaled_size.x, scaled_size.z) * data.face_scale,
		1: Vector2(scaled_size.x, scaled_size.z) * data.face_scale,
		2: Vector2(scaled_size.x, scaled_size.y) * data.face_scale,
		3: Vector2(scaled_size.x, scaled_size.y) * data.face_scale,
		4: Vector2(scaled_size.z, scaled_size.y) * data.face_scale,
		5: Vector2(scaled_size.z, scaled_size.y) * data.face_scale
	}

	for face_index in FACE_TRANSFORMS.keys():
		var face_node := DiceFaceView.new()
		face_node.name = FACE_TRANSFORMS[face_index].name
		face_node.position = FACE_TRANSFORMS[face_index].position * face_depths[face_index]
		face_node.rotation = FACE_TRANSFORMS[face_index].rotation
		_faces_root.add_child(face_node)
		face_node.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

		var face_data: DiceFaceData = null
		if face_index < data.faces.size():
			face_data = data.faces[face_index]
		if face_data == null:
			face_data = DiceFaceData.new()
			face_data.label_text = str(face_index + 1)
		face_node.setup(face_data, face_sizes[face_index])
