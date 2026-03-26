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
