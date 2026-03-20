extends RigidBody3D
class_name DiceView

const FACE_VIEW_SCENE := preload("res://ui/scenes/dice/die_face_view.tscn")
const FACE_TRANSFORMS := {
	0: {"basis": Basis.IDENTITY, "origin": Vector3(0, 0.505, 0)},
	1: {"basis": Basis(Vector3.RIGHT, PI), "origin": Vector3(0, -0.505, 0)},
	2: {"basis": Basis(Vector3.RIGHT, -PI * 0.5), "origin": Vector3(0, 0, 0.505)},
	3: {"basis": Basis(Vector3.RIGHT, PI * 0.5), "origin": Vector3(0, 0, -0.505)},
	4: {"basis": Basis(Vector3.FORWARD, PI * 0.5), "origin": Vector3(-0.505, 0, 0)},
	5: {"basis": Basis(Vector3.FORWARD, -PI * 0.5), "origin": Vector3(0.505, 0, 0)}
}

@export var dice_definition: DiceDefinition:
	set(value):
		dice_definition = value
		if is_node_ready():
			_rebuild()

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: MeshInstance3D = $BodyMesh

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	_rebuild()

func apply_throw(impulse: Vector3, torque: Vector3 = Vector3.ZERO) -> void:
	apply_central_impulse(impulse)
	apply_torque_impulse(torque)

func _rebuild() -> void:
	if dice_definition == null:
		return

	mass = dice_definition.mass

	var cube_size := dice_definition.cube_size
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * cube_size
	_body_mesh.mesh = box_mesh

	var body_material := StandardMaterial3D.new()
	body_material.albedo_texture = dice_definition.base_texture
	_body_mesh.material_override = body_material

	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3.ONE * cube_size
	_collision_shape.shape = box_shape

	for child in get_children():
		if child is DieFaceView:
			child.queue_free()

	var face_size := cube_size * 0.92
	var offset_scale := cube_size
	for face_index in FACE_TRANSFORMS.keys():
		var face_view: DieFaceView = FACE_VIEW_SCENE.instantiate()
		var transform_data: Dictionary = FACE_TRANSFORMS[face_index]
		face_view.transform = Transform3D(
			transform_data["basis"],
			transform_data["origin"] * offset_scale
		)
		add_child(face_view)
		face_view.owner = owner
		face_view.configure(dice_definition.get_face_content(face_index), dice_definition.base_texture, face_size)
