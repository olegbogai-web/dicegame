extends RefCounted
class_name DiceVisualRuntime


func refresh(
	dice: Node3D,
	node_graph: DiceNodeGraph,
	definition: DiceDefinition,
	extra_size_multiplier: Vector3,
	face_normals: Array[Vector3]
) -> void:
	if definition == null:
		_clear_visuals(node_graph)
		return

	var size := definition.get_resolved_size() * extra_size_multiplier
	node_graph.body_mesh.mesh = _build_box_mesh(size)
	node_graph.body_mesh.material_override = _build_body_material(definition)

	for index in node_graph.face_views.size():
		var face_view := node_graph.face_views[index]
		var normal: Vector3 = face_normals[index]
		var up := Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
		var offset := Vector3(
			normal.x * size.x * 0.5,
			normal.y * size.y * 0.5,
			normal.z * size.z * 0.5
		) + normal * 0.001
		face_view.transform = Transform3D(Basis.looking_at(normal, up, true), offset)
		face_view.apply_face(definition.get_face(index), _resolve_face_size(index, size))


func _clear_visuals(node_graph: DiceNodeGraph) -> void:
	node_graph.body_mesh.mesh = null
	node_graph.body_mesh.material_override = null
	for face_view in node_graph.face_views:
		face_view.visible = false


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


func _build_body_material(definition: DiceDefinition) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.base_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.roughness = definition.roughness
	material.metallic = definition.metallic
	if definition.texture != null:
		material.albedo_texture = definition.texture
	return material

