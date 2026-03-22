extends RefCounted
class_name AbilityRuntime


static func build_slot_conditions(ability: AbilityDefinition) -> Array[AbilityDiceCondition]:
	var conditions: Array[AbilityDiceCondition] = []
	if ability == null or ability.cost == null:
		return conditions
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		for _count in maxi(dice_condition.required_count, 0):
			conditions.append(dice_condition)
	return conditions


static func dice_matches_ability(dice: Dice, condition: AbilityDiceCondition, ability: AbilityDefinition) -> bool:
	if dice == null or condition == null:
		return false
	if not dice.sleeping or dice.is_being_dragged():
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


static func dice_satisfies_use_conditions(dice: Dice, ability: AbilityDefinition) -> bool:
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


static func find_payment_dice(ability: AbilityDefinition, dice_list: Array[Dice]) -> Array[Dice]:
	var slot_conditions := build_slot_conditions(ability)
	if slot_conditions.is_empty():
		return []
	return _find_payment_recursive(ability, slot_conditions, dice_list, 0, [], {})


static func can_pay_ability(ability: AbilityDefinition, dice_list: Array[Dice]) -> bool:
	if ability == null:
		return false
	if ability.cost == null or not ability.cost.requires_dice():
		return true
	return not find_payment_dice(ability, dice_list).is_empty()


static func _find_payment_recursive(
	ability: AbilityDefinition,
	slot_conditions: Array[AbilityDiceCondition],
	dice_list: Array[Dice],
	index: int,
	current_selection: Array[Dice],
	used_dice: Dictionary,
) -> Array[Dice]:
	if index >= slot_conditions.size():
		return current_selection.duplicate()

	var condition := slot_conditions[index]
	for dice in dice_list:
		if dice == null or used_dice.has(dice.get_instance_id()):
			continue
		if not dice_matches_ability(dice, condition, ability):
			continue
		used_dice[dice.get_instance_id()] = true
		current_selection.append(dice)
		var nested := _find_payment_recursive(ability, slot_conditions, dice_list, index + 1, current_selection, used_dice)
		if not nested.is_empty():
			return nested
		current_selection.pop_back()
		used_dice.erase(dice.get_instance_id())

	return []
