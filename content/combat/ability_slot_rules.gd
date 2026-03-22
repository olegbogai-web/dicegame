extends RefCounted
class_name AbilitySlotRules

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


static func dice_matches_ability_slot(dice: Dice, condition: AbilityDiceCondition, ability: AbilityDefinition) -> bool:
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

	return _dice_satisfies_use_conditions(dice, ability)


static func collect_ready_dice_for_ability(ability: AbilityDefinition, dice_list: Array[Dice], require_fully_stopped: bool = false) -> Array[Dice]:
	var resolved_dice: Array[Dice] = []
	var slot_conditions := build_slot_conditions(ability)
	if slot_conditions.is_empty():
		return resolved_dice

	var used_dice := {}
	for condition in slot_conditions:
		var matched_dice := _find_matching_die(condition, ability, dice_list, used_dice, require_fully_stopped)
		if matched_dice == null:
			return []
		used_dice[matched_dice.get_instance_id()] = true
		resolved_dice.append(matched_dice)
	return resolved_dice


static func can_pay_ability(ability: AbilityDefinition, dice_list: Array[Dice], require_fully_stopped: bool = false) -> bool:
	if ability == null:
		return false
	if build_slot_conditions(ability).is_empty():
		return true
	return not collect_ready_dice_for_ability(ability, dice_list, require_fully_stopped).is_empty()


static func _find_matching_die(
	condition: AbilityDiceCondition,
	ability: AbilityDefinition,
	dice_list: Array[Dice],
	used_dice: Dictionary,
	require_fully_stopped: bool
) -> Dice:
	for dice in dice_list:
		if dice == null or used_dice.has(dice.get_instance_id()):
			continue
		if dice.is_being_dragged() or dice.get_assigned_ability_slot_id() != &"":
			continue
		if require_fully_stopped and not dice.is_fully_stopped():
			continue
		if not dice_matches_ability_slot(dice, condition, ability):
			continue
		return dice
	return null


static func _dice_satisfies_use_conditions(dice: Dice, ability: AbilityDefinition) -> bool:
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
