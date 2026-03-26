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


func align_top_face_to_camera_down(
	dice: Node3D,
	face_normals: Array[Vector3],
	camera: Camera3D
) -> void:
	if camera == null:
		return

	var top_face_index := get_top_face_index(dice, face_normals)
	if top_face_index < 0 or top_face_index >= face_normals.size():
		return

	var resolved_basis := dice.global_transform.basis.orthonormalized()
	var local_top_normal: Vector3 = face_normals[top_face_index]
	var world_top_normal := (resolved_basis * local_top_normal).normalized()
	if world_top_normal.is_zero_approx():
		return

	var local_face_bottom := _resolve_local_face_bottom_direction(local_top_normal)
	var world_face_bottom := (resolved_basis * local_face_bottom).normalized()
	var world_camera_down := (-camera.global_transform.basis.y).normalized()

	var current_bottom_on_top_plane := (world_face_bottom - world_top_normal * world_face_bottom.dot(world_top_normal)).normalized()
	var target_bottom_on_top_plane := (world_camera_down - world_top_normal * world_camera_down.dot(world_top_normal)).normalized()

	if current_bottom_on_top_plane.is_zero_approx() or target_bottom_on_top_plane.is_zero_approx():
		return

	var correction_angle := current_bottom_on_top_plane.signed_angle_to(target_bottom_on_top_plane, world_top_normal)
	if is_zero_approx(correction_angle):
		return

	var correction_basis := Basis(world_top_normal, correction_angle)
	dice.global_transform.basis = (correction_basis * resolved_basis).orthonormalized()


func _resolve_local_face_bottom_direction(face_normal: Vector3) -> Vector3:
	var up := Vector3.UP if abs(face_normal.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
	var face_basis := Basis.looking_at(face_normal, up, true)
	return -face_basis.y.normalized()
