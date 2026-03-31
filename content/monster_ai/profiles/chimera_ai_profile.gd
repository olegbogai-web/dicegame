extends MonsterAiProfile
class_name ChimeraAiProfile

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")

var _turn_state_by_monster: Dictionary = {}


func decide_next_action(monster_index: int, battle_room, available_dice: Array[Dice]) -> MonsterAiDecision:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		return MonsterAiDecision.end_turn(&"monster_missing")
	if not battle_room.can_target_player():
		return MonsterAiDecision.end_turn(&"player_unavailable")

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		return MonsterAiDecision.end_turn(&"monster_view_missing")

	var turn_state := _resolve_turn_state(monster_index, battle_room)
	var strengthening := _find_ability_by_id(monster_view.abilities, "strengthening")
	if strengthening != null and not bool(turn_state.get("strengthening_used", false)):
		if _can_use_strengthening_by_any_three_dice_combination(strengthening, available_dice):
			turn_state["strengthening_used"] = true
			return MonsterAiDecision.use_ability(strengthening, {"kind": &"self"}, &"strengthening_priority")

	var clawed_series := _find_ability_by_id(monster_view.abilities, "clawed_series")
	if clawed_series != null and BattleAbilityRuntime.can_use_ability_with_dice(clawed_series, available_dice, true):
		return MonsterAiDecision.use_ability(clawed_series, {"kind": &"player"}, &"clawed_series_priority")

	return MonsterAiDecision.end_turn(&"abilities_unavailable")


func _resolve_turn_state(monster_index: int, battle_room) -> Dictionary:
	var state_key := _build_turn_key(monster_index, battle_room)
	for existing_key in _turn_state_by_monster.keys():
		if existing_key == state_key:
			continue
		if int(_turn_state_by_monster[existing_key].get("monster_index", -1)) == monster_index:
			_turn_state_by_monster.erase(existing_key)
	if not _turn_state_by_monster.has(state_key):
		_turn_state_by_monster[state_key] = {
			"monster_index": monster_index,
			"strengthening_used": false,
		}
	return _turn_state_by_monster[state_key]


func _build_turn_key(monster_index: int, battle_room) -> StringName:
	var turn_counter := int(battle_room.turn_counter)
	var current_monster_turn_index := int(battle_room.current_monster_turn_index)
	return StringName("%d:%d:%d" % [monster_index, turn_counter, current_monster_turn_index])


func _find_ability_by_id(abilities: Array[AbilityDefinition], ability_id: String) -> AbilityDefinition:
	for ability in abilities:
		if ability == null:
			continue
		if ability.ability_id == ability_id:
			return ability
	return null


func _can_use_strengthening_by_any_three_dice_combination(ability: AbilityDefinition, available_dice: Array[Dice]) -> bool:
	if ability == null:
		return false
	if available_dice.size() < 3:
		return false
	if not BattleAbilityRuntime.can_use_ability_with_dice(ability, available_dice, true):
		return false
	var ability_cost := ability.cost
	if ability_cost == null or ability_cost.dice_conditions.is_empty():
		return true
	var condition := ability_cost.dice_conditions[0] as AbilityDiceCondition
	if condition == null:
		return true
	var min_total := condition.min_total_value
	var max_total := condition.max_total_value
	if min_total <= 0 and max_total <= 0:
		return true
	var top_values: Array[int] = []
	for dice in available_dice:
		if dice == null or not is_instance_valid(dice):
			continue
		if not BattleAbilityRuntime.is_die_usable_for_ability(dice, ability, condition, true):
			continue
		top_values.append(dice.get_top_face_value())
	if top_values.size() < 3:
		return false
	top_values.sort()
	for left in range(0, top_values.size() - 2):
		var middle := left + 1
		var right := top_values.size() - 1
		while middle < right:
			var total := top_values[left] + top_values[middle] + top_values[right]
			if (min_total <= 0 or total >= min_total) and (max_total <= 0 or total <= max_total):
				return true
			if min_total > 0 and total < min_total:
				middle += 1
			else:
				right -= 1
	return false
