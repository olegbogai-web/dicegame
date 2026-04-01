extends RefCounted
class_name DiceDragController

const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")

var _is_dragging := false
var _drag_camera: Camera3D
var _drag_plane_height := 0.0
var _drag_target_height := 0.0
var _default_gravity_scale := 1.0
var _rotation_locked_before_drag := false


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

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if _is_dragging:
		stop_dragging(dice)
		return

	if not allow_drag_without_sleep and not dice.sleeping:
		return

	_start_dragging(dice, camera, position, drag_lift_height)


func physics_process(dice: RigidBody3D) -> void:
	if not _is_dragging:
		return

	_update_drag_position(dice)


func stop_dragging(dice: RigidBody3D) -> void:
	if not _is_dragging:
		return

	_is_dragging = false
	DiceMotionState.restore_dynamic_control(dice, _default_gravity_scale, _rotation_locked_before_drag)
	_drag_camera = null
	_drag_plane_height = 0.0
	_drag_target_height = 0.0
	_rotation_locked_before_drag = false


func _start_dragging(dice: RigidBody3D, camera: Camera3D, hit_position: Vector3, drag_lift_height: float) -> void:
	if camera == null:
		return

	_drag_camera = camera
	_drag_plane_height = drag_lift_height
	_drag_target_height = drag_lift_height
	_rotation_locked_before_drag = dice.lock_rotation
	_default_gravity_scale = DiceMotionState.begin_kinematic_control(dice, _rotation_locked_before_drag)
	_is_dragging = true
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
