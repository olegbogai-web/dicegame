extends RefCounted
class_name TestMonsterAI

const COMMON_ATTACK_ABILITY_ID := &"common_attack"


static func choose_action(monster_view, available_dice: Array[Dice]) -> Dictionary:
	if monster_view == null:
		return {}

	var common_attack := _find_common_attack(monster_view.abilities)
	if common_attack == null:
		return {}

	var selected_die := _find_matching_die(common_attack, available_dice)
	if selected_die == null:
		return {}

	return {
		"ability": common_attack,
		"target_descriptor": {
			"kind": &"player",
		},
		"consumed_dice": [selected_die],
		"end_turn_after_action": false,
	}


static func _find_common_attack(abilities: Array[AbilityDefinition]) -> AbilityDefinition:
	for ability in abilities:
		if ability != null and StringName(ability.ability_id) == COMMON_ATTACK_ABILITY_ID:
			return ability
	return null


static func _find_matching_die(ability: AbilityDefinition, available_dice: Array[Dice]) -> Dice:
	if ability == null or ability.cost == null or ability.cost.dice_conditions.is_empty():
		return null

	var dice_condition := ability.cost.dice_conditions[0] as AbilityDiceCondition
	if dice_condition == null:
		return null

	for dice in available_dice:
		if _can_pay_common_attack_with_die(dice, dice_condition, ability):
			return dice
	return null


static func _can_pay_common_attack_with_die(dice: Dice, dice_condition: AbilityDiceCondition, ability: AbilityDefinition) -> bool:
	if dice == null or dice.get_assigned_ability_slot_id() != &"":
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

	for use_condition in ability.use_conditions:
		if use_condition == null:
			continue
		if use_condition.predicate == &"selected_die_top_face_parity":
			var parity := String(use_condition.parameters.get("parity", ""))
			if parity == "even" and top_face_value % 2 != 0:
				return false
			if parity == "odd" and top_face_value % 2 == 0:
				return false

	return true
