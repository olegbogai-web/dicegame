extends RefCounted
class_name BattleTableAbilityActivationController

const SELECTED_FRAME_LIFT_Y := 0.4
const ACTIVATION_ANIMATION_DURATION := 0.5
const MONSTER_DICE_SNAP_DURATION := 0.18

var _host: Node
var _resolve_target_origin: Callable
var _resolve_slot_target_position: Callable


func configure(host: Node, resolve_target_origin: Callable, resolve_slot_target_position: Callable) -> void:
	_host = host
	_resolve_target_origin = resolve_target_origin
	_resolve_slot_target_position = resolve_slot_target_position


func activate_player_ability(
	battle_room: BattleRoom,
	frame_state: Dictionary,
	consumed_dice: Array[Dice],
	target_descriptor: Dictionary
) -> void:
	var ability := frame_state.get("ability") as AbilityDefinition
	if battle_room == null or ability == null:
		return
	await _activate_ability(
		frame_state,
		consumed_dice,
		target_descriptor,
		func() -> void:
			battle_room.activate_player_ability(ability, target_descriptor)
	)


func activate_monster_ability(
	battle_room: BattleRoom,
	frame_state: Dictionary,
	consumed_dice: Array[Dice],
	target_descriptor: Dictionary
) -> void:
	var ability := frame_state.get("ability") as AbilityDefinition
	var slot_targets: Array = frame_state.get("dice_places", [])
	if battle_room == null or ability == null:
		return
	await _animate_dice_to_ability_slots(consumed_dice, slot_targets)
	await _activate_ability(
		frame_state,
		consumed_dice,
		target_descriptor,
		func() -> void:
			var monster_index := int(frame_state.get("monster_index", -1))
			battle_room.activate_monster_ability(monster_index, ability, target_descriptor)
	)


func _animate_dice_to_ability_slots(consumed_dice: Array[Dice], dice_places: Array) -> void:
	if _host == null or consumed_dice.is_empty() or dice_places.is_empty():
		return

	var tween := _host.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var animated_any := false

	for index in mini(consumed_dice.size(), dice_places.size()):
		var dice := consumed_dice[index]
		var dice_place := dice_places[index] as MeshInstance3D
		if dice == null or not is_instance_valid(dice) or dice_place == null:
			continue
		dice.freeze = true
		var target_position := _resolve_slot_target_position.call(dice_place, dice)
		tween.tween_property(dice, "global_position", target_position, MONSTER_DICE_SNAP_DURATION)
		animated_any = true

	if animated_any:
		await tween.finished


func _activate_ability(
	frame_state: Dictionary,
	consumed_dice: Array[Dice],
	target_descriptor: Dictionary,
	activate_callback: Callable
) -> void:
	if _host == null:
		return

	var frame := frame_state.get("frame") as MeshInstance3D
	if frame == null or not is_instance_valid(frame):
		return

	var base_origin: Vector3 = frame_state.get("base_origin", frame.transform.origin)
	var target_origin := _resolve_target_origin.call(target_descriptor, base_origin)
	var lift_origin := Vector3(base_origin.x, base_origin.y + SELECTED_FRAME_LIFT_Y, base_origin.z)
	var half_duration := ACTIVATION_ANIMATION_DURATION * 0.5
	var tween := _host.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(frame, "transform:origin", lift_origin, half_duration * 0.3)
	tween.tween_property(frame, "transform:origin", target_origin, half_duration * 0.7)
	tween.tween_callback(func() -> void:
		for dice in consumed_dice:
			if is_instance_valid(dice):
				dice.queue_free()
		if activate_callback.is_valid():
			activate_callback.call()
	)
	tween.tween_property(frame, "transform:origin", base_origin, half_duration)
	await tween.finished
