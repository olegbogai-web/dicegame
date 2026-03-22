extends RefCounted
class_name BattleAbilityPresentation

const Dice = preload("res://content/dice/dice.gd")


static func build_slot_move_assignments(dice_assignments: Array[Dictionary], dice_places: Array[MeshInstance3D], position_resolver: Callable) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for index in range(mini(dice_assignments.size(), dice_places.size())):
		var assignment := dice_assignments[index]
		var dice := assignment.get("dice") as Dice
		var dice_place := dice_places[index]
		if dice == null or dice_place == null:
			continue
		moves.append({
			"dice": dice,
			"target_position": position_resolver.call(dice_place, dice),
		})
	return moves


static func move_dice_to_slots(host: Node, move_assignments: Array[Dictionary], duration: float = 0.2) -> void:
	if host == null or move_assignments.is_empty():
		return
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	for move_assignment in move_assignments:
		var dice := move_assignment.get("dice") as Dice
		if dice == null or not is_instance_valid(dice):
			continue
		var target_position: Vector3 = move_assignment.get("target_position", dice.global_position)
		dice.freeze = true
		dice.linear_velocity = Vector3.ZERO
		dice.angular_velocity = Vector3.ZERO
		tween.tween_property(dice, "global_position", target_position, duration)
	await tween.finished
	for move_assignment in move_assignments:
		var dice := move_assignment.get("dice") as Dice
		if dice == null or not is_instance_valid(dice):
			continue
		dice.global_position = move_assignment.get("target_position", dice.global_position)


static func play_ability_use(
	host: Node,
	frame: MeshInstance3D,
	base_origin: Vector3,
	consumed_dice: Array[Dice],
	target_origin: Vector3,
	resolve_callback: Callable,
	activation_duration: float,
	lift_height: float
) -> void:
	if host == null or frame == null or not is_instance_valid(frame):
		if resolve_callback.is_valid():
			resolve_callback.call()
		return

	var lift_origin := Vector3(base_origin.x, base_origin.y + lift_height, base_origin.z)
	var half_duration := activation_duration * 0.5
	var tween := host.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(frame, "transform:origin", lift_origin, half_duration * 0.3)
	tween.tween_property(frame, "transform:origin", target_origin, half_duration * 0.7)
	tween.tween_callback(func() -> void:
		for dice in consumed_dice:
			if is_instance_valid(dice):
				dice.queue_free()
		if resolve_callback.is_valid():
			resolve_callback.call()
	)
	tween.tween_property(frame, "transform:origin", base_origin, half_duration)
	await tween.finished
