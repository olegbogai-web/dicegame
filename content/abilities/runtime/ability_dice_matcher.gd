extends RefCounted
class_name AbilityDiceMatcher


func build_slot_conditions(ability: AbilityDefinition) -> Array[AbilityDiceCondition]:
	var conditions: Array[AbilityDiceCondition] = []
	if ability == null or ability.cost == null:
		return conditions
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		for _count in maxi(dice_condition.required_count, 0):
			conditions.append(dice_condition)
	return conditions


func find_matching_dice(ability: AbilityDefinition, dice_list: Array[Dice]) -> Array[Dice]:
	var matched_dice: Array[Dice] = []
	if ability == null:
		return matched_dice

	var available_dice := dice_list.duplicate()
	for condition in build_slot_conditions(ability):
		var matched_index := _find_first_matching_die_index(condition, ability, available_dice)
		if matched_index < 0:
			return []
		matched_dice.append(available_dice[matched_index])
		available_dice.remove_at(matched_index)

	return matched_dice


func can_pay_ability(ability: AbilityDefinition, dice_list: Array[Dice]) -> bool:
	if ability == null:
		return false
	if ability.cost == null or not ability.cost.requires_dice():
		return true
	return not find_matching_dice(ability, dice_list).is_empty()


func dice_matches_ability(dice: Dice, ability: AbilityDefinition, condition: AbilityDiceCondition) -> bool:
	if dice == null or condition == null:
		return false

	var top_face_value := dice.get_top_face_value()
	if top_face_value < 0 or not condition.matches_value(top_face_value):
		return false

	if condition.requires_face_filter():
		var top_face := dice.get_top_face()
		if top_face == null or not condition.accepted_face_ids.has(top_face.text_value):
			return false

	var dice_tags := dice.get_match_tags()
	for required_tag in condition.required_tags:
		if not dice_tags.has(required_tag):
			return false
	for forbidden_tag in condition.forbidden_tags:
		if dice_tags.has(forbidden_tag):
			return false

	return dice_satisfies_use_conditions(dice, ability)


func dice_satisfies_use_conditions(dice: Dice, ability: AbilityDefinition) -> bool:
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


func _find_first_matching_die_index(
	condition: AbilityDiceCondition,
	ability: AbilityDefinition,
	dice_list: Array[Dice]
) -> int:
	for index in dice_list.size():
		var dice := dice_list[index]
		if dice_matches_ability(dice, ability, condition):
			return index
	return -1
