extends RefCounted
class_name GlobalMapClickResolver


func is_event_icon_clicked(camera: Camera3D, event: InputEventMouseButton, collision_body: CollisionObject3D) -> bool:
	if camera == null or collision_body == null:
		return false
	if event == null or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return false

	var world := camera.get_world_3d()
	if world == null:
		return false

	var space_state := world.direct_space_state
	var ray_origin := camera.project_ray_origin(event.position)
	var ray_direction := camera.project_ray_normal(event.position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 300.0)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	return hit.get("collider") == collision_body
