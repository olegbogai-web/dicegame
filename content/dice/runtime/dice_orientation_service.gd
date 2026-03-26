extends RefCounted
class_name DiceOrientationService

const ALIGN_ANIMATION_DURATION := 0.5
const ALIGN_TWEEN_META_KEY := "align_top_face_tween"


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


func align_top_face_to_camera_bottom(dice: Node3D, face_normals: Array[Vector3], camera: Camera3D) -> bool:
	if dice == null or camera == null:
		return false

	var top_face_index := get_top_face_index(dice, face_normals)
	if top_face_index < 0 or top_face_index >= face_normals.size():
		return false

	var resolved_basis := dice.global_transform.basis.orthonormalized()
	var local_top_normal: Vector3 = face_normals[top_face_index].normalized()
	var world_top_normal := (resolved_basis * local_top_normal).normalized()

	var local_face_down := _get_face_local_down(face_normals[top_face_index])
	var world_face_down := (resolved_basis * local_face_down).normalized()
	var world_camera_down := (-camera.global_transform.basis.y).normalized()

	var projected_face_down := _project_to_plane(world_face_down, world_top_normal)
	var projected_camera_down := _project_to_plane(world_camera_down, world_top_normal)
	if projected_face_down.length_squared() < 0.000001 or projected_camera_down.length_squared() < 0.000001:
		return false

	var angle := projected_face_down.normalized().signed_angle_to(projected_camera_down.normalized(), world_top_normal)
	if is_zero_approx(angle):
		return true

	var existing_tween: Tween = null
	if dice.has_meta(ALIGN_TWEEN_META_KEY):
		existing_tween = dice.get_meta(ALIGN_TWEEN_META_KEY) as Tween
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()

	var initial_basis := dice.global_transform.basis.orthonormalized()
	var target_basis := initial_basis.rotated(world_top_normal, angle).orthonormalized()

	var tween := dice.create_tween()
	dice.set_meta(ALIGN_TWEEN_META_KEY, tween)
	tween.tween_method(_set_dice_global_basis.bind(dice), initial_basis, target_basis, ALIGN_ANIMATION_DURATION)
	tween.finished.connect(func() -> void:
		dice.global_transform = Transform3D(dice.global_transform.basis.orthonormalized(), dice.global_position)
		dice.remove_meta(ALIGN_TWEEN_META_KEY)
	)
	return true


func _get_face_local_down(normal: Vector3) -> Vector3:
	var local_up := Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
	var face_basis := Basis.looking_at(normal, local_up, true)
	return (face_basis * Vector3.DOWN).normalized()


func _project_to_plane(direction: Vector3, plane_normal: Vector3) -> Vector3:
	return direction - plane_normal * direction.dot(plane_normal)


func _set_dice_global_basis(basis_value: Basis, dice: Node3D) -> void:
	if dice == null:
		return
	dice.global_transform = Transform3D(basis_value.orthonormalized(), dice.global_position)
