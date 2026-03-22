extends RefCounted
class_name DiceMotionState

const Dice = preload("res://content/dice/dice.gd")


static func stop_motion(dice: RigidBody3D) -> void:
	if dice == null or not is_instance_valid(dice):
		return
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO


static func is_motionless(dice: RigidBody3D) -> bool:
	if dice == null or not is_instance_valid(dice):
		return false
	return (
		dice.linear_velocity.length_squared() <= 0.0001
		and dice.angular_velocity.length_squared() <= 0.0001
	)


static func is_fully_stopped(dice: Dice) -> bool:
	if dice == null or not is_instance_valid(dice):
		return false
	if dice.is_being_dragged():
		return false
	if not is_motionless(dice):
		return false
	return dice.sleeping or dice.has_completed_first_stop()


static func begin_kinematic_control(
	dice: RigidBody3D,
	lock_rotation: bool = true,
	next_sleeping: bool = false,
	gravity_scale: float = 0.0
) -> float:
	if dice == null or not is_instance_valid(dice):
		return gravity_scale
	var saved_gravity_scale := dice.gravity_scale
	dice.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	dice.freeze = true
	dice.gravity_scale = gravity_scale
	stop_motion(dice)
	dice.sleeping = next_sleeping
	dice.lock_rotation = lock_rotation
	return saved_gravity_scale


static func restore_dynamic_control(
	dice: RigidBody3D,
	gravity_scale: float,
	lock_rotation: bool,
	next_sleeping: bool = false
) -> void:
	if dice == null or not is_instance_valid(dice):
		return
	dice.freeze = false
	dice.gravity_scale = gravity_scale
	stop_motion(dice)
	dice.sleeping = next_sleeping
	dice.lock_rotation = lock_rotation
