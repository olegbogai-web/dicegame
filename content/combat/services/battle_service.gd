extends RefCounted
class_name BattleService

const BattleEnums = preload("res://content/combat/resources/battle_enums.gd")
const BattleCombatantScript = preload("res://content/combat/runtime/battle_combatant.gd")
const BattleDicePoolScript = preload("res://content/combat/runtime/battle_dice_pool.gd")
const BattleTargetingServiceScript = preload("res://content/combat/services/battle_targeting_service.gd")

var _rng := RandomNumberGenerator.new()
var _targeting := BattleTargetingServiceScript.new()


func _init() -> void:
	_rng.randomize()


func create_test_battle(player: Player, player_sprite: Texture2D, monsters: Array[MonsterDefinition]) -> BattleState:
	var state := BattleState.new()
	state.battle_id = "test_battle"
	state.combatants.append(BattleCombatantScript.from_player(player, player_sprite, 0))
	for index in monsters.size():
		var monster := monsters[index]
		if monster == null:
			continue
		state.combatants.append(BattleCombatantScript.from_monster(monster, index))
	state.turn_order = _build_turn_order(state)
	start_player_turn(state)
	return state


func start_player_turn(state: BattleState) -> void:
	if _finish_if_needed(state):
		return
	var player := state.get_player()
	if player == null or not player.is_alive():
		_finish_battle(state, BattleEnums.ResultType.PLAYER_DEFEAT, &"player_dead")
		return
	_start_turn_for_combatant(state, player, BattleEnums.Phase.AWAITING_PLAYER_ACTION)
	state.append_log("Ход игрока: %s." % player.display_name)


func end_player_turn_and_run_monsters(state: BattleState) -> void:
	if state == null or state.is_finished:
		return
	if state.active_turn != null:
		state.active_turn.end_reason = &"player_end_turn"
	var enemies := state.get_enemies()
	enemies.sort_custom(_sort_enemies_by_turn_order)
	for enemy in enemies:
		if state.is_finished:
			break
		if enemy == null or not enemy.is_alive():
			continue
		_start_turn_for_combatant(state, enemy, BattleEnums.Phase.MONSTER_TURN)
		_execute_monster_turn(state, enemy)
		if _finish_if_needed(state):
			break
	if not state.is_finished:
		state.round_number += 1
		start_player_turn(state)


func get_valid_player_targets(state: BattleState, ability: AbilityDefinition) -> Array[BattleCombatant]:
	if state == null or ability == null:
		return []
	return _targeting.get_valid_targets(state, state.get_player(), ability.target_rule)


func can_activate_ability(state: BattleState, source: BattleCombatant, ability: AbilityDefinition, dice_ids: Array[int]) -> Dictionary:
	if state == null or source == null or ability == null or state.active_turn == null:
		return {"ok": false, "reason": "missing_state"}
	if state.active_turn.turn_owner_id != source.combatant_id:
		return {"ok": false, "reason": "not_active_owner"}
	var selected_dice := state.active_turn.dice_pool.get_dice_by_ids(dice_ids)
	if ability.cost != null and ability.cost.requires_dice():
		var validation := _validate_dice_cost(ability, selected_dice)
		if not bool(validation.get("ok", false)):
			return validation
	if not _validate_use_conditions(ability, selected_dice):
		return {"ok": false, "reason": "use_condition_failed"}
	return {"ok": true}


func activate_player_ability(state: BattleState, ability: AbilityDefinition, dice_ids: Array[int], target_ids: PackedStringArray) -> Dictionary:
	var player := state.get_player()
	var validation := can_activate_ability(state, player, ability, dice_ids)
	if not bool(validation.get("ok", false)):
		return validation
	var targets := _resolve_targets_by_ids(state, target_ids)
	return _activate_ability(state, player, ability, dice_ids, targets)


func _execute_monster_turn(state: BattleState, enemy: BattleCombatant) -> void:
	state.append_log("Ход монстра: %s." % enemy.display_name)
	for ability in enemy.abilities:
		if ability == null:
			continue
		var available_dice := state.active_turn.dice_pool.get_available_dice()
		var dice_ids := _pick_ai_dice_for_ability(ability, available_dice)
		if dice_ids.is_empty() and ability.cost != null and ability.cost.requires_dice():
			continue
		var validation := can_activate_ability(state, enemy, ability, dice_ids)
		if not bool(validation.get("ok", false)):
			continue
		var targets := _targeting.resolve_ai_targets(state, enemy, ability.target_rule)
		_activate_ability(state, enemy, ability, dice_ids, targets)
		return
	state.append_log("%s заканчивает ход без действий." % enemy.display_name)


func _activate_ability(state: BattleState, source: BattleCombatant, ability: AbilityDefinition, dice_ids: Array[int], targets: Array[BattleCombatant]) -> Dictionary:
	if state == null or source == null or ability == null:
		return {"ok": false, "reason": "missing_state"}
	var resolved_targets := targets
	if ability.target_rule != null and ability.target_rule.requires_target_selection() and resolved_targets.is_empty():
		return {"ok": false, "reason": "missing_target"}
	state.phase = BattleEnums.Phase.RESOLVING_ACTION
	state.append_log("%s использует %s." % [source.display_name, ability.display_name])
	if not dice_ids.is_empty():
		state.active_turn.dice_pool.consume_dice(dice_ids)
	state.active_turn.activated_ability_ids.append(ability.ability_id)
	for effect in ability.effects:
		if effect == null:
			continue
		_apply_effect(state, source, effect, resolved_targets)
		if _finish_if_needed(state):
			break
	state.active_turn.refresh_available_dice()
	if not state.is_finished:
		state.phase = BattleEnums.Phase.AWAITING_PLAYER_ACTION if source.is_player_controlled else BattleEnums.Phase.MONSTER_TURN
	return {"ok": true}


func _apply_effect(state: BattleState, source: BattleCombatant, effect: AbilityEffectDefinition, targets: Array[BattleCombatant]) -> void:
	var repeat_count := maxi(effect.repeat_count, 1)
	for _repeat_index in repeat_count:
		match String(effect.effect_type):
			"damage":
				for target in targets:
					if target == null:
						continue
					var dealt := target.take_damage(effect.magnitude)
					state.append_log("%s наносит %d урона %s." % [source.display_name, dealt, target.display_name])
			"healing":
				var healing_targets := targets if not targets.is_empty() else [source]
				for target in healing_targets:
					if target == null:
						continue
					var healed := target.heal(effect.magnitude)
					state.append_log("%s восстанавливает %d HP для %s." % [source.display_name, healed, target.display_name])
			_:
				state.append_log("Эффект %s пока не поддержан." % effect.effect_type)
		if _finish_if_needed(state):
			return


func _start_turn_for_combatant(state: BattleState, combatant: BattleCombatant, phase: BattleEnums.Phase) -> void:
	var dice_pool := BattleDicePoolScript.new()
	dice_pool.roll_for_combatant(combatant, _rng)
	var turn_state := BattleTurnState.new()
	turn_state.turn_owner_id = combatant.combatant_id
	turn_state.round_number = state.round_number
	turn_state.can_end_turn = true
	turn_state.dice_pool = dice_pool
	turn_state.refresh_available_dice()
	state.active_turn = turn_state
	state.active_combatant_id = combatant.combatant_id
	state.phase = phase


func _build_turn_order(state: BattleState) -> PackedStringArray:
	var order := PackedStringArray()
	var player := state.get_player()
	if player != null:
		order.append(player.combatant_id)
	var enemies := state.get_enemies(true)
	enemies.sort_custom(_sort_enemies_by_turn_order)
	for enemy in enemies:
		order.append(enemy.combatant_id)
	return order


func _sort_enemies_by_turn_order(a: BattleCombatant, b: BattleCombatant) -> bool:
	if a.get_available_dice_count() == b.get_available_dice_count():
		return a.spawn_index < b.spawn_index
	return a.get_available_dice_count() > b.get_available_dice_count()


func _validate_dice_cost(ability: AbilityDefinition, selected_dice: Array[Dictionary]) -> Dictionary:
	if ability == null or ability.cost == null:
		return {"ok": true}
	var expected_count := 0
	for condition in ability.cost.dice_conditions:
		if condition == null:
			continue
		expected_count += maxi(condition.required_count, 0)
	if selected_dice.size() != expected_count:
		return {"ok": false, "reason": "wrong_dice_count"}

	var dice_index := 0
	for condition in ability.cost.dice_conditions:
		if condition == null:
			continue
		for _required_index in maxi(condition.required_count, 0):
			if dice_index >= selected_dice.size():
				return {"ok": false, "reason": "missing_die"}
			var die_data: Dictionary = selected_dice[dice_index]
			var die_value := int(die_data.get("value", -1))
			if not condition.matches_value(die_value):
				return {"ok": false, "reason": "dice_value_mismatch"}
			dice_index += 1
	return {"ok": true}


func _validate_use_conditions(ability: AbilityDefinition, selected_dice: Array[Dictionary]) -> bool:
	for condition in ability.use_conditions:
		if condition == null:
			continue
		if condition.predicate == &"selected_die_top_face_parity":
			if selected_dice.is_empty():
				return false
			var parity := String(condition.parameters.get("parity", ""))
			for die_data in selected_dice:
				var die_value := int(die_data.get("value", 0))
				if parity == "even" and die_value % 2 != 0:
					return false
				if parity == "odd" and die_value % 2 == 0:
					return false
	return true


func _pick_ai_dice_for_ability(ability: AbilityDefinition, available_dice: Array[Dictionary]) -> Array[int]:
	if ability == null or ability.cost == null or not ability.cost.requires_dice():
		return []
	var selected_ids: Array[int] = []
	var remaining_dice := available_dice.duplicate(true)
	for condition in ability.cost.dice_conditions:
		if condition == null:
			continue
		for _required_index in maxi(condition.required_count, 0):
			var matched_index := -1
			for index in remaining_dice.size():
				var die_data: Dictionary = remaining_dice[index]
				if condition.matches_value(int(die_data.get("value", -1))):
					matched_index = index
					break
			if matched_index == -1:
				return []
			selected_ids.append(int(remaining_dice[matched_index].get("dice_id", -1)))
			remaining_dice.remove_at(matched_index)
	return selected_ids


func _resolve_targets_by_ids(state: BattleState, target_ids: PackedStringArray) -> Array[BattleCombatant]:
	var targets: Array[BattleCombatant] = []
	for target_id in target_ids:
		var target := state.get_combatant(String(target_id))
		if target != null:
			targets.append(target)
	return targets


func _finish_if_needed(state: BattleState) -> bool:
	if state == null or state.is_finished:
		return state != null and state.is_finished
	var player := state.get_player()
	if player == null or not player.is_alive():
		_finish_battle(state, BattleEnums.ResultType.PLAYER_DEFEAT, &"player_dead")
		return true
	if state.get_enemies().is_empty():
		_finish_battle(state, BattleEnums.ResultType.PLAYER_VICTORY, &"all_monsters_dead")
		return true
	return false


func _finish_battle(state: BattleState, result_type: BattleEnums.ResultType, reason: StringName) -> void:
	state.is_finished = true
	state.phase = BattleEnums.Phase.FINISHED
	state.result.result_type = result_type
	state.result.reason = reason
	state.result.surviving_ids.clear()
	state.result.defeated_ids.clear()
	for combatant in state.combatants:
		if combatant.is_alive():
			state.result.surviving_ids.append(combatant.combatant_id)
		else:
			state.result.defeated_ids.append(combatant.combatant_id)
	match result_type:
		BattleEnums.ResultType.PLAYER_VICTORY:
			state.append_log("Бой завершен: победа игрока.")
		BattleEnums.ResultType.PLAYER_DEFEAT:
			state.append_log("Бой завершен: поражение игрока.")
		_:
			state.append_log("Бой завершен.")
