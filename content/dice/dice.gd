@tool
extends RigidBody3D
class_name Dice

const FACE_NAMES := [&"Front", &"Back", &"Right", &"Left", &"Top", &"Bottom"]
const FACE_NORMALS := [
	Vector3.FORWARD,
	Vector3.BACK,
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.UP,
	Vector3.DOWN,
]

@export var definition: DiceDefinition
@export var extra_size_multiplier: Vector3 = Vector3.ONE

var _visual_root: Node3D
var _body_mesh: MeshInstance3D
var _face_views: Array[DiceFaceView] = []
var _bound_definition: DiceDefinition


func _enter_tree() -> void:
	_ensure_nodes()
	_bind_definition()
	_refresh_visuals()


func _ready() -> void:
	_ensure_nodes()
	_bind_definition()
	_refresh_visuals()


func _exit_tree() -> void:
	_unbind_definition()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_bind_definition()
		_refresh_visuals()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if definition == null:
		warnings.append("Dice requires a DiceDefinition resource.")
	elif definition.faces.size() != DiceDefinition.FACE_COUNT:
		warnings.append("DiceDefinition should define exactly 6 faces for a standard cube.")
	return warnings


func _bind_definition() -> void:
	if _bound_definition == definition:
		return

	_unbind_definition()
	_bound_definition = definition

	if _bound_definition != null and not _bound_definition.changed.is_connected(_on_definition_changed):
		_bound_definition.changed.connect(_on_definition_changed)

	update_configuration_warnings()


func _unbind_definition() -> void:
	if _bound_definition != null and _bound_definition.changed.is_connected(_on_definition_changed):
		_bound_definition.changed.disconnect(_on_definition_changed)
	_bound_definition = null


func _on_definition_changed() -> void:
	_refresh_visuals()
	update_configuration_warnings()


func _ensure_nodes() -> void:
	if _visual_root == null:
		_visual_root = Node3D.new()
		_visual_root.name = "Visual"
		add_child(_visual_root)
		_visual_root.owner = self if Engine.is_editor_hint() else null

	if _body_mesh == null:
		_body_mesh = MeshInstance3D.new()
		_body_mesh.name = "Body"
		_visual_root.add_child(_body_mesh)
		_body_mesh.owner = self if Engine.is_editor_hint() else null

	if _face_views.size() == 0:
		for face_name in FACE_NAMES:
			var face_view := DiceFaceView.new()
			face_view.name = face_name
			_visual_root.add_child(face_view)
			face_view.owner = self if Engine.is_editor_hint() else null
			_face_views.append(face_view)


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return

	_ensure_nodes()
	_bind_definition()

	if definition == null:
		_body_mesh.mesh = null
		for face_view in _face_views:
			face_view.visible = false
		return

	var size := definition.get_resolved_size() * extra_size_multiplier
	_body_mesh.mesh = _build_box_mesh(size)
	_body_mesh.material_override = _build_body_material()

	for index in _face_views.size():
		var face_view := _face_views[index]
		var normal: Vector3 = FACE_NORMALS[index]
		var up := Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
		var offset := Vector3(
			normal.x * size.x * 0.5,
			normal.y * size.y * 0.5,
			normal.z * size.z * 0.5,
		) + normal * 0.001
		face_view.transform = Transform3D(Basis.looking_at(normal, up, true), offset)
		face_view.apply_face(definition.get_face(index), _resolve_face_size(index, size))


func _resolve_face_size(face_index: int, size: Vector3) -> Vector2:
	match face_index:
		0, 1:
			return Vector2(size.x, size.y)
		2, 3:
			return Vector2(size.z, size.y)
		4, 5:
			return Vector2(size.x, size.z)
		_:
			return Vector2.ONE * min(size.x, size.y)


func _build_box_mesh(size: Vector3) -> BoxMesh:
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	return box_mesh


func _build_body_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.base_color
	material.roughness = definition.roughness
	material.metallic = definition.metallic
	if definition.texture != null:
		material.albedo_texture = definition.texture
	return material
