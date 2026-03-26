extends RefCounted
class_name GlobalMapClickResolver

@export var click_pick_radius: float = 120.0

var _camera: Camera3D
var _event_icon: Node3D


func setup(camera: Camera3D, event_icon: Node3D) -> void:
	_camera = camera
	_event_icon = event_icon


func is_event_icon_clicked(screen_position: Vector2) -> bool:
	if _camera == null or _event_icon == null or not _event_icon.visible:
		return false
	var projected_position := _camera.unproject_position(_event_icon.global_position)
	if projected_position == Vector2.INF:
		return false
	return projected_position.distance_to(screen_position) <= click_pick_radius
