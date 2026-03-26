extends RefCounted
class_name GlobalMapEventClickHandler

var _camera: Camera3D
var _event_click_body: CollisionObject3D


func setup(camera: Camera3D, event_click_body: CollisionObject3D) -> void:
	_camera = camera
	_event_click_body = event_click_body


func is_event_clicked(event: InputEvent) -> bool:
	if _camera == null or _event_click_body == null:
		return false
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false

	var world_3d := _camera.get_world_3d()
	if world_3d == null:
		return false
	var ray_origin := _camera.project_ray_origin(mouse_event.position)
	var ray_direction := _camera.project_ray_normal(mouse_event.position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 200.0)
	var hit := world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return hit.get("collider") == _event_click_body
