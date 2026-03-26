extends RefCounted
class_name GlobalMapPathPresenter


func collect_path_waypoints(root: Node3D, hero_icon: MeshInstance3D, event_icon: MeshInstance3D) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if root == null or hero_icon == null or event_icon == null:
		return result

	var dashes: Array[MeshInstance3D] = []
	for child in root.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh_child := child as MeshInstance3D
		if not mesh_child.name.begins_with("dash"):
			continue
		dashes.append(mesh_child)

	dashes.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return hero_icon.global_position.distance_to(a.global_position) < hero_icon.global_position.distance_to(b.global_position)
	)

	for dash in dashes:
		result.append(dash.global_position)
	result.append(event_icon.global_position)
	return result
