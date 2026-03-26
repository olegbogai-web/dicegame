extends RefCounted
class_name DiceOrientationService


func get_top_face_index(dice: Node3D, face_normals: Array[Vector3]) -> int:
	var resolved_basis := dice.global_transform.basis.orthonormalized()
	var top_face_index := -1
	var top_face_alignment := -INF

	for index in face_normals.size():
		var world_normal := resolved_basis * face_normals[index]
		var alignment := world_normal.dot(Vector3.UP)
		if alignment > top_face_alignment:
			top_face_alignment = alignment
			top_face_index = index

	return top_face_index


func align_top_face_bottom_to_camera(
	dice: Node3D,
	face_normals: Array[Vector3],
	camera: Camera3D
) -> bool:
	if dice == null or not is_instance_valid(dice):
		return false
	if camera == null or not is_instance_valid(camera):
		return false
	if face_normals.is_empty():
		return false

	var top_face_index := get_top_face_index(dice, face_normals)
	if top_face_index < 0 or top_face_index >= face_normals.size():
		return false

	var resolved_basis := dice.global_transform.basis.orthonormalized()
	var top_normal_world := (resolved_basis * face_normals[top_face_index]).normalized()
	if top_normal_world.length_squared() <= 0.000001:
		return false

	var face_up_local := _get_face_up_local(face_normals[top_face_index])
	var current_face_down_world := (resolved_basis * -face_up_local).normalized()
	current_face_down_world = _project_on_plane(current_face_down_world, top_normal_world)
	if current_face_down_world.length_squared() <= 0.000001:
		return false
	current_face_down_world = current_face_down_world.normalized()

	var camera_down_world := -camera.global_transform.basis.y
	var target_face_down_world := _project_on_plane(camera_down_world, top_normal_world)
	if target_face_down_world.length_squared() <= 0.000001:
		return false
	target_face_down_world = target_face_down_world.normalized()

	var cross := current_face_down_world.cross(target_face_down_world)
	var signed_angle := atan2(top_normal_world.dot(cross), current_face_down_world.dot(target_face_down_world))
	if abs(signed_angle) <= 0.0001:
		return false

	var rotated_basis := (Basis(top_normal_world, signed_angle) * resolved_basis).orthonormalized()
	var transform := dice.global_transform
	transform.basis = rotated_basis
	dice.global_transform = transform
	return true


func _project_on_plane(vector: Vector3, normal: Vector3) -> Vector3:
	return vector - normal * vector.dot(normal)


func _get_face_up_local(face_normal: Vector3) -> Vector3:
	return Vector3.UP if abs(face_normal.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
