extends RefCounted
class_name MonsterTurnRuntime

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")


static func run_turn(host: Node, context: Dictionary) -> StringName:
	var battle_room = context.get("battle_room")
	if battle_room == null:
		return &"missing_battle_room"
	var monster_index := int(context.get("monster_index", -1))
	if monster_index < 0 or not battle_room.can_target_monster(monster_index):
		return &"monster_unavailable"

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		return &"monster_view_missing"

	await _wait_until_turn_dice_stop(host, context)

	while battle_room != null and battle_room.is_monster_turn() and not battle_room.is_battle_over():
		var turn_dice: Array[Dice] = _call_dice_provider(context)
		var available_dice := BattleAbilityRuntime.filter_ready_dice(turn_dice, true)
		if available_dice.is_empty():
			return &"no_dice"
		if not BattleAbilityRuntime.can_use_any_ability(monster_view.abilities, available_dice, true):
			return &"no_usable_abilities"

		var ai_profile: MonsterAiProfile = monster_view.ai_profile
		if ai_profile == null:
			return &"missing_ai_profile"
		var decision := ai_profile.decide_next_action(monster_index, battle_room, available_dice)
		if decision == null or decision.is_end_turn():
			return decision.reason if decision != null else &"ai_signal"
		if decision.ability == null:
			return &"invalid_ability"
		var consumed_dice := BattleAbilityRuntime.collect_dice_for_ability(decision.ability, available_dice, true)
		if consumed_dice.size() < BattleAbilityRuntime.get_required_dice_count(decision.ability):
			return &"unpayable_decision"

		var execute_ability: Callable = context.get("execute_ability", Callable())
		if not execute_ability.is_valid():
			return &"missing_execute_ability"
		await execute_ability.call(monster_index, decision.ability, decision.target_descriptor, consumed_dice)
		await _wait_until_turn_dice_stop(host, context)

	return &"turn_interrupted"


static func _wait_until_turn_dice_stop(host: Node, context: Dictionary) -> void:
	var are_dice_stopped: Callable = context.get("are_turn_dice_stopped", Callable())
	if not are_dice_stopped.is_valid():
		return
	while host != null and is_instance_valid(host) and host.is_inside_tree() and not are_dice_stopped.call():
		await host.get_tree().physics_frame


static func _call_dice_provider(context: Dictionary) -> Array[Dice]:
	var provide_turn_dice: Callable = context.get("provide_turn_dice", Callable())
	if not provide_turn_dice.is_valid():
		return []
	return provide_turn_dice.call()
