extends RefCounted
class_name DiceOrientationService

const CARDINAL_AXES: Array[Vector3] = [
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.UP,
	Vector3.DOWN,
	Vector3.BACK,
	Vector3.FORWARD,
]


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


func get_upright_basis(dice: Node3D, face_normals: Array[Vector3]) -> Basis:
	var resolved_basis := dice.global_transform.basis.orthonormalized()
	var top_face_index := get_top_face_index(dice, face_normals)
	if top_face_index < 0:
		return resolved_basis

	var desired_forward := _project_horizontal(resolved_basis * Vector3.FORWARD)
	if desired_forward.is_zero_approx():
		desired_forward = _project_horizontal(resolved_basis * Vector3.RIGHT)

	var best_basis := resolved_basis
	var best_score := -INF
	for candidate in _get_upright_candidates(face_normals[top_face_index]):
		var candidate_forward := _project_horizontal(candidate * Vector3.FORWARD)
		var score := 0.0 if desired_forward.is_zero_approx() or candidate_forward.is_zero_approx() else candidate_forward.dot(desired_forward)
		if score > best_score:
			best_score = score
			best_basis = candidate

	return best_basis.orthonormalized()


func _get_upright_candidates(top_face_normal: Vector3) -> Array[Basis]:
	var candidates: Array[Basis] = []
	for x_axis in CARDINAL_AXES:
		for y_axis in CARDINAL_AXES:
			if is_equal_approx(absf(x_axis.dot(y_axis)), 1.0):
				continue
			var z_axis := x_axis.cross(y_axis)
			if z_axis.is_zero_approx():
				continue
			var candidate := Basis(x_axis, y_axis, z_axis).orthonormalized()
			if candidate.determinant() <= 0.0:
				continue
			if (candidate * top_face_normal).dot(Vector3.UP) < 0.999:
				continue
			candidates.append(candidate)
	return candidates


func _project_horizontal(vector: Vector3) -> Vector3:
	var projected := vector - Vector3.UP * vector.dot(Vector3.UP)
	if projected.is_zero_approx():
		return Vector3.ZERO
	return projected.normalized()
