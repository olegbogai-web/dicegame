extends RefCounted
class_name DiceSlotSnapController

var _assigned_slot_id: StringName = &""
var _target_position := Vector3.ZERO
var _target_basis := Basis.IDENTITY
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


func assign_slot(dice: RigidBody3D, slot_id: StringName, target_position: Vector3, target_basis: Basis = Basis.IDENTITY) -> void:
	if _assigned_slot_id == slot_id:
		_target_position = target_position
		_target_basis = target_basis.orthonormalized()
		return

	clear_slot(dice)
	_assigned_slot_id = slot_id
	_target_position = target_position
	_target_basis = target_basis.orthonormalized()


func clear_slot(dice: RigidBody3D) -> void:
	if _is_attracting or _is_snapped:
		_restore_physics(dice)
	_assigned_slot_id = &""
	_target_position = Vector3.ZERO
	_target_basis = Basis.IDENTITY
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
	_saved_gravity_scale = dice.gravity_scale
	dice.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	dice.freeze = true
	dice.gravity_scale = 0.0
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.sleeping = false
	dice.lock_rotation = true
	_is_attracting = true


func _update_attraction(dice: RigidBody3D, delta: float) -> void:
	var next_position := dice.global_position.move_toward(_target_position, _snap_speed * delta)
	dice.global_position = next_position
	dice.global_basis = _interpolate_basis(dice.global_basis, _target_basis, delta)
	if next_position.distance_to(_target_position) <= 0.01:
		_snap_now(dice)


func _snap_now(dice: RigidBody3D) -> void:
	dice.global_position = _target_position
	dice.global_basis = _target_basis
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.sleeping = true
	_is_attracting = false
	_is_snapped = true


func _hold_to_slot(dice: RigidBody3D) -> void:
	dice.global_position = _target_position
	dice.global_basis = _target_basis
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	dice.freeze = true
	dice.gravity_scale = 0.0
	dice.lock_rotation = true
	dice.sleeping = true


func _restore_physics(dice: RigidBody3D) -> void:
	dice.freeze = false
	dice.gravity_scale = _saved_gravity_scale
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.sleeping = false
	dice.lock_rotation = false


func _interpolate_basis(from_basis: Basis, to_basis: Basis, delta: float) -> Basis:
	var weight := clampf(_snap_speed * delta, 0.0, 1.0)
	var from_quaternion := from_basis.orthonormalized().get_rotation_quaternion()
	var to_quaternion := to_basis.orthonormalized().get_rotation_quaternion()
	return Basis(from_quaternion.slerp(to_quaternion, weight)).orthonormalized()
