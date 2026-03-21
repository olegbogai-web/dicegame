extends RefCounted
class_name DiceDragController

var _is_dragging := false
var _drag_camera: Camera3D
var _drag_plane_height := 0.0
var _drag_target_height := 0.0
var _default_gravity_scale := 1.0


func handle_input_event(
	dice: RigidBody3D,
	camera: Camera3D,
	event: InputEvent,
	position: Vector3,
	drag_lift_height: float,
	allow_drag_without_sleep: bool = false
) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not allow_drag_without_sleep and not dice.sleeping:
				return
			_start_dragging(dice, camera, position, drag_lift_height)
		else:
			stop_dragging(dice)


func physics_process(dice: RigidBody3D) -> void:
	if not _is_dragging:
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		stop_dragging(dice)
		return

	_update_drag_position(dice)


func stop_dragging(dice: RigidBody3D) -> void:
	if not _is_dragging:
		return

	_is_dragging = false
	dice.freeze = false
	dice.gravity_scale = _default_gravity_scale
	dice.lock_rotation = false
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	_drag_camera = null
	_drag_plane_height = 0.0
	_drag_target_height = 0.0


func _start_dragging(dice: RigidBody3D, camera: Camera3D, hit_position: Vector3, drag_lift_height: float) -> void:
	if camera == null:
		return

	_drag_camera = camera
	_drag_plane_height = drag_lift_height
	_drag_target_height = drag_lift_height
	_default_gravity_scale = dice.gravity_scale
	dice.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	dice.freeze = true
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.gravity_scale = 0.0
	_is_dragging = true
	dice.lock_rotation = false
	_update_drag_position(dice)


func _update_drag_position(dice: RigidBody3D) -> void:
	if not _is_dragging or _drag_camera == null:
		return

	var mouse_position := dice.get_viewport().get_mouse_position()
	var ray_origin := _drag_camera.project_ray_origin(mouse_position)
	var ray_direction := _drag_camera.project_ray_normal(mouse_position)
	var denominator := ray_direction.y
	if abs(denominator) < 0.0001:
		return

	var distance := (_drag_plane_height - ray_origin.y) / denominator
	if distance < 0.0:
		return

	var target_hit_position := ray_origin + ray_direction * distance
	var target_position := target_hit_position
	target_position.y = _drag_target_height
	dice.global_position = target_position


func is_dragging() -> bool:
	return _is_dragging
