extends RefCounted
class_name BattleActivationAnimationRuntime

const Dice = preload("res://content/dice/dice.gd")
const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")
const DEFAULT_DICE_MOVE_DURATION := 0.24
const ABILITY_ACTIVATION_CONSUME_COUNTER_META := &"ability_activation_consume_counter"


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
	pre_activate_delay_sec: float,
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
	if pre_activate_delay_sec > 0.0 and host != null and is_instance_valid(host) and host.is_inside_tree():
		await host.get_tree().create_timer(pre_activate_delay_sec).timeout

	var half_duration := activation_duration * 0.5
	var lift_origin := Vector3(base_origin.x, base_origin.y + selected_frame_lift_y, base_origin.z)
	var tween := host.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(frame, "transform:origin", lift_origin, half_duration * 0.3)
	tween.tween_property(frame, "transform:origin", target_origin, half_duration * 0.7)
	tween.tween_callback(func() -> void:
		if on_activate.is_valid():
			on_activate.call()
		for dice in consumed_dice:
			if not is_instance_valid(dice):
				continue
			if _should_consume_dice_on_current_activation(dice):
				dice.queue_free()
				continue
			DiceMotionState.restore_dynamic_control(dice, dice.gravity_scale, dice.lock_rotation, true)
	)
	tween.tween_property(frame, "transform:origin", base_origin, half_duration)
	await tween.finished
	if on_finished.is_valid():
		on_finished.call()


static func _prepare_dice_for_scripted_motion(dice: Dice) -> void:
	DiceMotionState.begin_kinematic_control(dice, true, true, dice.gravity_scale)


static func _should_consume_dice_on_current_activation(dice: Dice) -> bool:
	if dice == null or not is_instance_valid(dice):
		return false
	var consume_after_activations := 1
	if dice.definition != null:
		consume_after_activations = maxi(dice.definition.ability_activations_before_consume, 1)
	var consume_counter := int(dice.get_meta(ABILITY_ACTIVATION_CONSUME_COUNTER_META, 0)) + 1
	dice.set_meta(ABILITY_ACTIVATION_CONSUME_COUNTER_META, consume_counter)
	return consume_counter >= consume_after_activations
