extends RefCounted
class_name BattleAbilityRuntime

const Dice = preload("res://content/dice/dice.gd")
const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")
const JOKER_FACE_ID := &"joker"


static func build_slot_conditions(ability: AbilityDefinition) -> Array[AbilityDiceCondition]:
	var conditions: Array[AbilityDiceCondition] = []
	if ability == null or ability.cost == null:
		return conditions
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		for _count in maxi(dice_condition.get_slot_count(), 0):
			conditions.append(dice_condition)
	return conditions


static func can_use_ability_with_dice(
	ability: AbilityDefinition,
	dice_list: Array[Dice],
	require_stopped: bool = false
) -> bool:
	if ability == null:
		return false
	if ability.cost == null or not ability.cost.requires_dice():
		return true
	if _has_joker_override_dice(dice_list, require_stopped):
		return true
	return collect_dice_for_ability(ability, dice_list, require_stopped).size() >= get_required_dice_count(ability)


static func can_use_any_ability(
	abilities: Array[AbilityDefinition],
	dice_list: Array[Dice],
	require_stopped: bool = false
) -> bool:
	for ability in abilities:
		if can_use_ability_with_dice(ability, dice_list, require_stopped):
			return true
	return false


static func get_required_dice_count(ability: AbilityDefinition) -> int:
	if ability == null or ability.cost == null:
		return 0
	var total_required := 0
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		total_required += dice_condition.get_min_selected_count()
	return total_required


static func collect_dice_for_ability(
	ability: AbilityDefinition,
	dice_list: Array[Dice],
	require_stopped: bool = false
) -> Array[Dice]:
	var selected: Array[Dice] = []
	if ability == null:
		return selected
	if ability.cost == null or not ability.cost.requires_dice():
		return selected

	var available_dice := _filter_candidate_dice(dice_list, require_stopped)
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		var matched_dice := _collect_dice_for_condition(ability, dice_condition, available_dice, require_stopped)
		if matched_dice.size() < dice_condition.get_min_selected_count():
			selected.clear()
			return selected
		for matched_dice_item in matched_dice:
			available_dice.erase(matched_dice_item)
			selected.append(matched_dice_item)
	return selected


static func filter_ready_dice(dice_list: Array[Dice], require_stopped: bool = false) -> Array[Dice]:
	return _filter_candidate_dice(dice_list, require_stopped)


static func is_die_usable_for_ability(
	dice: Dice,
	ability: AbilityDefinition,
	dice_condition: AbilityDiceCondition,
	require_stopped: bool = false
) -> bool:
	if dice == null or not is_instance_valid(dice):
		return false
	if dice_condition == null:
		return false
	if require_stopped and not is_die_fully_stopped(dice):
		return false
	var top_face_value := dice.get_top_face_value()
	if top_face_value < 0 or not dice_condition.matches_value(top_face_value):
		return false
	if dice_condition.requires_face_filter():
		var top_face := dice.get_top_face()
		if top_face == null or not dice_condition.accepted_face_ids.has(top_face.text_value):
			return false
	var dice_tags := dice.get_match_tags()
	for required_tag in dice_condition.required_tags:
		if not dice_tags.has(required_tag):
			return false
	for forbidden_tag in dice_condition.forbidden_tags:
		if dice_tags.has(forbidden_tag):
			return false
	return _satisfies_ability_use_conditions(dice, ability)


static func is_die_fully_stopped(dice: Dice) -> bool:
	return DiceMotionState.is_fully_stopped(dice)


static func _filter_candidate_dice(dice_list: Array[Dice], require_stopped: bool) -> Array[Dice]:
	var filtered: Array[Dice] = []
	for dice in dice_list:
		if dice == null or not is_instance_valid(dice):
			continue
		if require_stopped and not is_die_fully_stopped(dice):
			continue
		filtered.append(dice)
	filtered.sort_custom(func(left: Dice, right: Dice) -> bool:
		return left.get_top_face_value() > right.get_top_face_value()
	)
	return filtered


static func _collect_dice_for_condition(
	ability: AbilityDefinition,
	dice_condition: AbilityDiceCondition,
	available_dice: Array[Dice],
	require_stopped: bool
) -> Array[Dice]:
	var candidates: Array[Dice] = []
	for dice in available_dice:
		if is_die_usable_for_ability(dice, ability, dice_condition, require_stopped):
			candidates.append(dice)

	var min_count := dice_condition.get_min_selected_count()
	var max_count := mini(dice_condition.get_max_selected_count(), candidates.size())
	if min_count <= 0:
		return []
	if candidates.size() < min_count:
		return []
	for selected_count in range(min_count, max_count + 1):
		var selected_for_count: Array[Dice] = []
		if _has_total_value_constraint(dice_condition):
			selected_for_count = _collect_dice_with_total_value(dice_condition, candidates, selected_count)
		else:
			selected_for_count = _collect_dice_with_count(dice_condition, candidates, selected_count)
		if selected_for_count.is_empty():
			continue
		if dice_condition.matches_total_value(_sum_dice_values(selected_for_count)):
			return selected_for_count
	return []


static func _has_total_value_constraint(dice_condition: AbilityDiceCondition) -> bool:
	if dice_condition == null:
		return false
	return dice_condition.min_total_value > 0 or dice_condition.max_total_value > 0


static func _collect_dice_with_total_value(
	dice_condition: AbilityDiceCondition,
	candidates: Array[Dice],
	required_count: int
) -> Array[Dice]:
	if required_count <= 0 or candidates.size() < required_count:
		return []
	var selected: Array[Dice] = []
	if _collect_dice_with_total_value_backtrack(dice_condition, candidates, required_count, 0, selected):
		return selected
	return []


static func _collect_dice_with_total_value_backtrack(
	dice_condition: AbilityDiceCondition,
	candidates: Array[Dice],
	required_count: int,
	start_index: int,
	selected: Array[Dice]
) -> bool:
	if selected.size() == required_count:
		var total := _sum_dice_values(selected)
		return dice_condition.matches_total_value(total)

	var remaining_slots := required_count - selected.size()
	var max_start := candidates.size() - remaining_slots
	for candidate_index in range(start_index, max_start + 1):
		var candidate := candidates[candidate_index]
		if candidate == null:
			continue
		selected.append(candidate)
		if _collect_dice_with_total_value_backtrack(dice_condition, candidates, required_count, candidate_index + 1, selected):
			return true
		selected.pop_back()
	return false


static func _collect_dice_with_count(
	dice_condition: AbilityDiceCondition,
	candidates: Array[Dice],
	required_count: int
) -> Array[Dice]:
	if dice_condition.requires_same_value:
		return _collect_same_value_dice(candidates, required_count)
	if dice_condition.requires_unique_values:
		return _collect_unique_value_dice(candidates, required_count)
	return candidates.slice(0, required_count)


static func _collect_same_value_dice(candidates: Array[Dice], required_count: int) -> Array[Dice]:
	var dice_by_value := {}
	for dice in candidates:
		var top_face_value := dice.get_top_face_value()
		if not dice_by_value.has(top_face_value):
			dice_by_value[top_face_value] = []
		var same_value_bucket: Array = dice_by_value[top_face_value]
		same_value_bucket.append(dice)
		dice_by_value[top_face_value] = same_value_bucket

	var sorted_values := dice_by_value.keys()
	sorted_values.sort()
	sorted_values.reverse()
	for top_face_value in sorted_values:
		var same_value_dice: Array[Dice] = []
		for bucket_dice in dice_by_value[top_face_value]:
			if bucket_dice is Dice:
				same_value_dice.append(bucket_dice as Dice)
		if same_value_dice.size() >= required_count:
			return same_value_dice.slice(0, required_count)
	return []


static func _collect_unique_value_dice(candidates: Array[Dice], required_count: int) -> Array[Dice]:
	var selected: Array[Dice] = []
	var used_values := {}
	for dice in candidates:
		var top_face_value := dice.get_top_face_value()
		if used_values.has(top_face_value):
			continue
		used_values[top_face_value] = true
		selected.append(dice)
		if selected.size() >= required_count:
			break
	return selected if selected.size() >= required_count else []


static func _sum_dice_values(dice_list: Array[Dice]) -> int:
	var total_value := 0
	for dice in dice_list:
		if dice == null or not is_instance_valid(dice):
			continue
		total_value += maxi(dice.get_top_face_value(), 0)
	return total_value


static func _satisfies_ability_use_conditions(dice: Dice, ability: AbilityDefinition) -> bool:
	if dice == null or ability == null:
		return false
	for condition in ability.use_conditions:
		if condition == null:
			continue
		if condition.predicate == &"selected_die_top_face_parity":
			var parity := String(condition.parameters.get("parity", ""))
			var top_face_value := dice.get_top_face_value()
			if parity == "even" and top_face_value % 2 != 0:
				return false
			if parity == "odd" and top_face_value % 2 == 0:
				return false
	return true


static func _has_joker_override_dice(dice_list: Array[Dice], require_stopped: bool) -> bool:
	for dice in dice_list:
		if dice == null or not is_instance_valid(dice):
			continue
		if require_stopped and not is_die_fully_stopped(dice):
			continue
		var top_face := dice.get_top_face()
		if top_face == null:
			continue
		if StringName(top_face.text_value) == JOKER_FACE_ID:
			return true
	return false
