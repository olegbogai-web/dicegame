extends RefCounted
class_name DiceSlotSnapController

const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")

var _assigned_slot_id: StringName = &""
var _target_position := Vector3.ZERO
var _snap_distance := 0.5
var _snap_speed := 6.5
var _is_snapped := false
var _is_attracting := false
var _saved_gravity_scale := 1.0


func configure(snap_distance: float, snap_speed: float) -> void:
	_snap_distance = max(snap_distance, 0.0)
	_snap_speed = max(snap_speed, 0.01)


func physics_process(dice: RigidBody3D, delta: float, is_dragging: bool) -> void:
	if not has_assigned_slot() or is_dragging:
		return

	if _is_snapped:
		_hold_to_slot(dice)
		return

	if not _is_attracting:
		if dice.global_position.distance_to(_target_position) > _snap_distance:
			return
		_begin_attraction(dice)

	_update_attraction(dice, delta)


func assign_slot(dice: RigidBody3D, slot_id: StringName, target_position: Vector3) -> void:
	if _assigned_slot_id == slot_id:
		_target_position = target_position
		return

	clear_slot(dice)
	_assigned_slot_id = slot_id
	_target_position = target_position


func clear_slot(dice: RigidBody3D) -> void:
	if _is_attracting or _is_snapped:
		_restore_physics(dice)
	_assigned_slot_id = &""
	_target_position = Vector3.ZERO
	_is_snapped = false
	_is_attracting = false


func prepare_for_manual_drag(dice: RigidBody3D, event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false

	var was_attached := _is_snapped or _is_attracting
	if was_attached:
		clear_slot(dice)
	return was_attached


func has_assigned_slot() -> bool:
	return _assigned_slot_id != &""


func get_assigned_slot_id() -> StringName:
	return _assigned_slot_id


func is_snapped() -> bool:
	return _is_snapped


func _begin_attraction(dice: RigidBody3D) -> void:
	_saved_gravity_scale = DiceMotionState.begin_kinematic_control(dice)
	_is_attracting = true


func _update_attraction(dice: RigidBody3D, delta: float) -> void:
	var next_position := dice.global_position.move_toward(_target_position, _snap_speed * delta)
	dice.global_position = next_position
	if next_position.distance_to(_target_position) <= 0.01:
		_snap_now(dice)


func _snap_now(dice: RigidBody3D) -> void:
	dice.global_position = _target_position
	DiceMotionState.stop_motion(dice)
	dice.sleeping = true
	_is_attracting = false
	_is_snapped = true


func _hold_to_slot(dice: RigidBody3D) -> void:
	dice.global_position = _target_position
	DiceMotionState.begin_kinematic_control(dice, true, true, 0.0)


func _restore_physics(dice: RigidBody3D) -> void:
	DiceMotionState.restore_dynamic_control(dice, _saved_gravity_scale, false)
