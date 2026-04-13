extends RefCounted
class_name MonsterTurnRuntime

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const DICE_STOP_WAIT_TIMEOUT_SEC := 5.0
const POST_ABILITY_DELAY_SEC := 0.5


static func run_turn(host: Node, context: Dictionary) -> StringName:
	var battle_room = context.get("battle_room")
	if battle_room == null:
		_log_debug("turn aborted: missing_battle_room")
		return &"missing_battle_room"
	var monster_index := int(context.get("monster_index", -1))
	if monster_index < 0 or not battle_room.can_target_monster(monster_index):
		_log_debug("turn aborted: monster_unavailable (index=%d)" % monster_index)
		return &"monster_unavailable"

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		_log_debug("turn aborted: monster_view_missing (index=%d)" % monster_index)
		return &"monster_view_missing"
	_log_debug("turn started: monster=%s index=%d" % [String(monster_view.combatant_id), monster_index])

	var initial_wait_result := await _wait_until_turn_dice_stop(host, context)
	if initial_wait_result == &"no_dice_left":
		_log_debug("turn finished: no_dice_before_ai_start (monster=%s index=%d)" % [String(monster_view.combatant_id), monster_index])
		return &"no_dice"
	if initial_wait_result == &"timeout":
		_log_debug("turn warning: dice wait timeout before ai start (monster=%s index=%d)" % [String(monster_view.combatant_id), monster_index])

	while battle_room != null and battle_room.is_monster_turn() and not battle_room.is_battle_over():
		var available_dice := await _resolve_ready_dice_for_decision(host, context)
		if available_dice.is_empty():
			_log_debug("turn finished: no_dice (monster=%s index=%d)" % [String(monster_view.combatant_id), monster_index])
			return &"no_dice"
		var activatable_abilities := _collect_activatable_abilities(monster_view.abilities, battle_room)
		if activatable_abilities.is_empty():
			_log_debug("turn finished: no_activatable_abilities (monster=%s index=%d)" % [String(monster_view.combatant_id), monster_index])
			return &"no_activatable_abilities"
		if not BattleAbilityRuntime.can_use_any_ability(activatable_abilities, available_dice, true):
			_log_debug("turn finished: no_usable_abilities (monster=%s index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
			return &"no_usable_abilities"

		var ai_profile: MonsterAiProfile = monster_view.ai_profile
		if ai_profile == null:
			_log_debug("turn aborted: missing_ai_profile (monster=%s index=%d)" % [String(monster_view.combatant_id), monster_index])
			return &"missing_ai_profile"
		var decision := ai_profile.decide_next_action(monster_index, battle_room, available_dice)
		if decision == null or decision.is_end_turn():
			_log_debug("turn finished by ai signal: %s (monster=%s index=%d)" % [String(decision.reason if decision != null else &"ai_signal"), String(monster_view.combatant_id), monster_index])
			return decision.reason if decision != null else &"ai_signal"
		if decision.ability == null:
			_log_debug("turn aborted: invalid_ability (monster=%s index=%d)" % [String(monster_view.combatant_id), monster_index])
			return &"invalid_ability"
		_log_debug("ai selected ability: %s (monster=%s index=%d, reason=%s)" % [decision.ability.ability_id, String(monster_view.combatant_id), monster_index, String(decision.reason)])
		var consumed_dice := BattleAbilityRuntime.collect_dice_for_ability(decision.ability, available_dice, true)
		if consumed_dice.size() < BattleAbilityRuntime.get_required_dice_count(decision.ability):
			_log_debug("turn finished: unpayable_decision ability=%s (monster=%s index=%d)" % [decision.ability.ability_id, String(monster_view.combatant_id), monster_index])
			return &"unpayable_decision"

		var execute_ability: Callable = context.get("execute_ability", Callable())
		if not execute_ability.is_valid():
			_log_debug("turn aborted: missing_execute_ability (monster=%s index=%d)" % [String(monster_view.combatant_id), monster_index])
			return &"missing_execute_ability"
		await execute_ability.call(monster_index, decision.ability, decision.target_descriptor, consumed_dice)
		await _wait_delay(host, context)

	_log_debug("turn interrupted: owner no longer active for monster index=%d" % monster_index)
	return &"turn_interrupted"


static func _resolve_ready_dice_for_decision(host: Node, context: Dictionary) -> Array[Dice]:
	var turn_dice: Array[Dice] = _call_dice_provider(context)
	var available_dice := BattleAbilityRuntime.filter_ready_dice(turn_dice, true)
	if not available_dice.is_empty() or turn_dice.is_empty():
		return available_dice

	var wait_result := await _wait_until_turn_dice_stop(host, context)
	turn_dice = _call_dice_provider(context)
	available_dice = BattleAbilityRuntime.filter_ready_dice(turn_dice, true)
	if wait_result == &"timeout" and available_dice.is_empty() and not turn_dice.is_empty():
		_log_debug("dice wait timeout fallback: using non-settled turn dice (%d)" % turn_dice.size())
		return turn_dice
	return available_dice


static func _wait_until_turn_dice_stop(host: Node, context: Dictionary) -> StringName:
	var are_dice_stopped: Callable = context.get("are_turn_dice_stopped", Callable())
	if not are_dice_stopped.is_valid():
		return &"missing_stop_predicate"
	var wait_started_at_msec := Time.get_ticks_msec()
	while host != null and is_instance_valid(host) and host.is_inside_tree() and not are_dice_stopped.call():
		var turn_dice := _call_dice_provider(context)
		if turn_dice.is_empty():
			_log_debug("dice wait interrupted: no_turn_dice_left")
			return &"no_dice_left"
		var wait_elapsed_sec := float(Time.get_ticks_msec() - wait_started_at_msec) / 1000.0
		if wait_elapsed_sec >= DICE_STOP_WAIT_TIMEOUT_SEC:
			_log_debug("dice wait timeout reached: %.2fs (continue turn safely)" % wait_elapsed_sec)
			return &"timeout"
		await host.get_tree().physics_frame
	return &"stopped"


static func _call_dice_provider(context: Dictionary) -> Array[Dice]:
	var provide_turn_dice: Callable = context.get("provide_turn_dice", Callable())
	if not provide_turn_dice.is_valid():
		return []
	return provide_turn_dice.call()


static func _wait_delay(host: Node, context: Dictionary) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var delay_sec := maxf(float(context.get("post_ability_delay_sec", POST_ABILITY_DELAY_SEC)), 0.0)
	if delay_sec <= 0.0:
		return
	await host.get_tree().create_timer(delay_sec).timeout


static func _collect_activatable_abilities(abilities: Array[AbilityDefinition], battle_room) -> Array[AbilityDefinition]:
	var activatable: Array[AbilityDefinition] = []
	for ability in abilities:
		if ability == null:
			continue
		if battle_room == null or not battle_room.can_activate_current_turn_ability(ability):
			continue
		activatable.append(ability)
	return activatable


static func _log_debug(message: String) -> void:
	print("[Debug][MonsterAI] %s" % message)
