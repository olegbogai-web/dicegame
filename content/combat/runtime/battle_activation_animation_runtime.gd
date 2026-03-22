extends RefCounted
class_name BattleActivationAnimationRuntime

const Dice = preload("res://content/dice/dice.gd")
const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")
const DEFAULT_DICE_MOVE_DURATION := 0.24


static func move_dice_to_places(host: Node, dice_assignments: Array[Dictionary], duration: float = DEFAULT_DICE_MOVE_DURATION) -> void:
	if host == null or dice_assignments.is_empty():
		return
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	for assignment in dice_assignments:
		var dice := assignment.get("dice") as Dice
		if dice == null or not is_instance_valid(dice):
			continue
		_prepare_dice_for_scripted_motion(dice)
		var target_position: Vector3 = assignment.get("target_position", dice.global_position)
		tween.tween_property(dice, "global_position", target_position, duration)
	await tween.finished


static func play_ability_use_animation(
	host: Node,
	frame: MeshInstance3D,
	base_origin: Vector3,
	target_origin: Vector3,
	consumed_dice: Array[Dice],
	dice_assignments: Array[Dictionary],
	activation_duration: float,
	selected_frame_lift_y: float,
	on_activate: Callable,
	on_finished: Callable = Callable()
) -> void:
	if host == null or frame == null or not is_instance_valid(frame):
		if on_activate.is_valid():
			on_activate.call()
		if on_finished.is_valid():
			on_finished.call()
		return

	await move_dice_to_places(host, dice_assignments)

	var half_duration := activation_duration * 0.5
	var lift_origin := Vector3(base_origin.x, base_origin.y + selected_frame_lift_y, base_origin.z)
	var tween := host.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(frame, "transform:origin", lift_origin, half_duration * 0.3)
	tween.tween_property(frame, "transform:origin", target_origin, half_duration * 0.7)
	tween.tween_callback(func() -> void:
		for dice in consumed_dice:
			if is_instance_valid(dice):
				dice.queue_free()
		if on_activate.is_valid():
			on_activate.call()
	)
	tween.tween_property(frame, "transform:origin", base_origin, half_duration)
	await tween.finished
	if on_finished.is_valid():
		on_finished.call()


static func _prepare_dice_for_scripted_motion(dice: Dice) -> void:
	DiceMotionState.begin_kinematic_control(dice, true, true, dice.gravity_scale)
