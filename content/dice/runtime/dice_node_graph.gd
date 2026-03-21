extends RefCounted
class_name DiceNodeGraph

var visual_root: Node3D
var collision_shape: CollisionShape3D
var body_mesh: MeshInstance3D
var face_views: Array[DiceFaceView] = []


func ensure_nodes(dice: Node3D, face_names: Array[StringName]) -> void:
	_ensure_visual_root(dice)
	_ensure_collision_shape(dice)
	_ensure_body_mesh(dice)
	if not face_names.is_empty():
		_ensure_face_views(dice, face_names)


func _ensure_visual_root(dice: Node3D) -> void:
	if is_instance_valid(visual_root):
		return

	visual_root = dice.get_node_or_null(^"Visual") as Node3D
	if visual_root == null:
		visual_root = Node3D.new()
		visual_root.name = "Visual"
		dice.add_child(visual_root)
		visual_root.owner = dice if Engine.is_editor_hint() else null


func _ensure_collision_shape(dice: Node3D) -> void:
	if is_instance_valid(collision_shape):
		return

	collision_shape = dice.get_node_or_null(^"Collision") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "Collision"
		dice.add_child(collision_shape)
		collision_shape.owner = dice if Engine.is_editor_hint() else null


func _ensure_body_mesh(dice: Node3D) -> void:
	_ensure_visual_root(dice)
	if is_instance_valid(body_mesh):
		return

	body_mesh = visual_root.get_node_or_null(^"Body") as MeshInstance3D
	if body_mesh == null:
		body_mesh = MeshInstance3D.new()
		body_mesh.name = "Body"
		visual_root.add_child(body_mesh)
		body_mesh.owner = dice if Engine.is_editor_hint() else null


func _ensure_face_views(dice: Node3D, face_names: Array[StringName]) -> void:
	_ensure_visual_root(dice)
	if face_views.size() == face_names.size() and _has_all_face_views():
		return

	face_views.clear()
	for face_name in face_names:
		var face_view := visual_root.get_node_or_null(NodePath(String(face_name))) as DiceFaceView
		if face_view == null:
			face_view = DiceFaceView.new()
			face_view.name = face_name
			visual_root.add_child(face_view)
			face_view.owner = dice if Engine.is_editor_hint() else null
		face_views.append(face_view)


func _has_all_face_views() -> bool:
	for face_view in face_views:
		if not is_instance_valid(face_view):
			return false
	return true
