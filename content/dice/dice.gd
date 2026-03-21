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
const DEFAULT_FRICTION := 0.25
const DEFAULT_BOUNCE := 0.7
const DEFAULT_LINEAR_DAMP := 0.25
const DEFAULT_ANGULAR_DAMP := 0.25

@export var definition: DiceDefinition
@export var extra_size_multiplier: Vector3 = Vector3.ONE

@export_category("Drag")
@export var drag_lift_height: float = 0.12

var _visual_root: Node3D
var _collision_shape: CollisionShape3D
var _body_mesh: MeshInstance3D
var _face_views: Array[DiceFaceView] = []
var _bound_definition: DiceDefinition
var _is_dragging := false
var _drag_camera: Camera3D
var _drag_plane_height := 0.0
var _default_gravity_scale := 1.0
var _drag_body_offset := Vector3.ZERO


func _enter_tree() -> void:
	_ensure_nodes()
	_apply_physics_defaults()
	_bind_definition()
	_refresh_visuals()


func _ready() -> void:
	_ensure_nodes()
	_apply_physics_defaults()
	_bind_definition()
	_refresh_visuals()
	input_ray_pickable = true
	set_physics_process(false)


func _exit_tree() -> void:
	_stop_dragging()
	_unbind_definition()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_apply_physics_defaults()
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


func _input_event(camera: Camera3D, event: InputEvent, position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_dragging(camera, position)
		else:
			_stop_dragging()


func _physics_process(_delta: float) -> void:
	if not _is_dragging:
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_dragging()
		return

	_update_drag_position()


func _ensure_nodes() -> void:
	if _visual_root == null:
		_visual_root = Node3D.new()
		_visual_root.name = "Visual"
		add_child(_visual_root)
		_visual_root.owner = self if Engine.is_editor_hint() else null

	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "Collision"
		add_child(_collision_shape)
		_collision_shape.owner = self if Engine.is_editor_hint() else null

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


func _apply_physics_defaults() -> void:
	linear_damp = DEFAULT_LINEAR_DAMP
	angular_damp = DEFAULT_ANGULAR_DAMP

	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()

	physics_material_override.friction = DEFAULT_FRICTION
	physics_material_override.bounce = DEFAULT_BOUNCE


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return

	_ensure_nodes()
	_bind_definition()

	if definition == null:
		if _collision_shape != null:
			_collision_shape.shape = null
		_body_mesh.mesh = null
		for face_view in _face_views:
			face_view.visible = false
		return

	var size := definition.get_resolved_size() * extra_size_multiplier
	_collision_shape.shape = _build_box_shape(size)
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


func _build_box_shape(size: Vector3) -> BoxShape3D:
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	return box_shape


func _build_box_mesh(size: Vector3) -> BoxMesh:
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	return box_mesh


func _build_body_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.base_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.roughness = definition.roughness
	material.metallic = definition.metallic
	if definition.texture != null:
		material.albedo_texture = definition.texture
	return material


func _start_dragging(camera: Camera3D, hit_position: Vector3) -> void:
	if camera == null:
		return

	_drag_camera = camera
	_drag_plane_height = hit_position.y + drag_lift_height
	_drag_body_offset = global_position - hit_position
	_default_gravity_scale = gravity_scale
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	gravity_scale = 0.0
	_is_dragging = true
	set_physics_process(true)
	_update_drag_position()


func _stop_dragging() -> void:
	if not _is_dragging:
		return

	_is_dragging = false
	set_physics_process(false)
	freeze = false
	gravity_scale = _default_gravity_scale
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_drag_camera = null
	_drag_body_offset = Vector3.ZERO


func _update_drag_position() -> void:
	if not _is_dragging or _drag_camera == null:
		return

	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _drag_camera.project_ray_origin(mouse_position)
	var ray_direction := _drag_camera.project_ray_normal(mouse_position)
	var denominator := ray_direction.y
	if abs(denominator) < 0.0001:
		return

	var distance := (_drag_plane_height - ray_origin.y) / denominator
	if distance < 0.0:
		return

	var target_hit_position := ray_origin + ray_direction * distance
	var target_position := target_hit_position + _drag_body_offset
	target_position.y = _drag_plane_height + _drag_body_offset.y
	global_position = target_position
