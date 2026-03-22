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


func get_nearest_upright_basis(dice: Node3D, face_normals: Array[Vector3]) -> Basis:
	var current_basis := dice.global_transform.basis.orthonormalized()
	var top_face_index := get_top_face_index(dice, face_normals)
	if top_face_index < 0:
		return current_basis

	var target_forward := _get_reference_horizontal_axis(current_basis, Vector3.FORWARD)
	var use_right_axis := target_forward.is_zero_approx()
	if use_right_axis:
		target_forward = _get_reference_horizontal_axis(current_basis, Vector3.RIGHT)

	var best_basis := _get_base_upright_basis(top_face_index)
	var best_alignment := -INF

	for step in 4:
		var candidate_basis := Basis(Vector3.UP, step * PI * 0.5) * _get_base_upright_basis(top_face_index)
		var candidate_axis := Vector3.FORWARD if not use_right_axis else Vector3.RIGHT
		var candidate_forward := _get_reference_horizontal_axis(candidate_basis, candidate_axis)
		if candidate_forward.is_zero_approx():
			continue
		var alignment := candidate_forward.dot(target_forward)
		if alignment > best_alignment:
			best_alignment = alignment
			best_basis = candidate_basis

	return best_basis.orthonormalized()


func _get_base_upright_basis(top_face_index: int) -> Basis:
	match top_face_index:
		0:
			return Basis(Vector3.RIGHT, -PI * 0.5)
		1:
			return Basis(Vector3.RIGHT, PI * 0.5)
		2:
			return Basis(Vector3.FORWARD, PI * 0.5)
		3:
			return Basis(Vector3.FORWARD, -PI * 0.5)
		4:
			return Basis.IDENTITY
		5:
			return Basis(Vector3.RIGHT, PI)
		_:
			return Basis.IDENTITY


func _get_reference_horizontal_axis(basis: Basis, local_axis: Vector3) -> Vector3:
	var horizontal_axis := (basis * local_axis).slide(Vector3.UP)
	if horizontal_axis.length_squared() <= 0.0001:
		return Vector3.ZERO
	return horizontal_axis.normalized()
