extends RefCounted
class_name GlobalMapFlowOrchestrator


func build_road_waypoints(hero_icon: Node3D, dashes: Array[Node3D], event_icon: Node3D) -> Array[Vector3]:
	var waypoints: Array[Vector3] = []
	for dash in dashes:
		if dash == null:
			continue
		waypoints.append(dash.global_position)
	if event_icon != null:
		waypoints.append(event_icon.global_position)

	if hero_icon == null:
		return waypoints

	waypoints.sort_custom(func(a: Vector3, b: Vector3):
		return hero_icon.global_position.distance_to(a) < hero_icon.global_position.distance_to(b)
	)
	return waypoints
