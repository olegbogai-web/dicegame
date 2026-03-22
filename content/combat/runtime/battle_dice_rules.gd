extends RefCounted
class_name BattleDiceRules

const Dice = preload("res://content/dice/dice.gd")


static func get_board_dice(board: Node) -> Array[Dice]:
	var dice_list: Array[Dice] = []
	if board == null:
		return dice_list
	for child in board.get_children():
		if child is Dice and is_instance_valid(child):
			dice_list.append(child as Dice)
	return dice_list


static func get_dice_for_owner(board: Node, owner: StringName, monster_index: int = -1) -> Array[Dice]:
	var filtered: Array[Dice] = []
	for dice in get_board_dice(board):
		if not _matches_owner(dice, owner, monster_index):
			continue
		filtered.append(dice)
	return filtered


static func are_all_dice_stopped(dice_list: Array[Dice]) -> bool:
	for dice in dice_list:
		if dice == null or not is_instance_valid(dice):
			continue
		if not dice.is_completely_stopped():
			return false
	return true


static func get_available_dice(dice_list: Array[Dice], require_stopped: bool = true) -> Array[Dice]:
	var available: Array[Dice] = []
	for dice in dice_list:
		if dice == null or not is_instance_valid(dice):
			continue
		if dice.is_being_dragged():
			continue
		if dice.get_assigned_ability_slot_id() != &"":
			continue
		if require_stopped and not dice.is_completely_stopped():
			continue
		available.append(dice)
	return available


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


static func can_use_ability_with_dice(ability: AbilityDefinition, dice_list: Array[Dice]) -> bool:
	return not build_dice_assignments_for_ability(ability, dice_list).is_empty() or get_required_dice_slots(ability) == 0


static func build_dice_assignments_for_ability(ability: AbilityDefinition, dice_list: Array[Dice]) -> Array[Dictionary]:
	var assignments: Array[Dictionary] = []
	var slot_conditions := build_slot_conditions(ability)
	if slot_conditions.is_empty():
		return assignments

	var available_dice := get_available_dice(dice_list, true)
	var used_dice := {}
	for condition in slot_conditions:
		var matched_dice := _find_matching_dice_for_condition(condition, ability, available_dice, used_dice)
		if matched_dice == null:
			return []
		used_dice[matched_dice.get_instance_id()] = true
		assignments.append({
			"dice": matched_dice,
			"condition": condition,
		})
	return assignments


static func dice_matches_slot(dice: Dice, condition: AbilityDiceCondition, ability: AbilityDefinition) -> bool:
	if dice == null or condition == null:
		return false
	if not dice.is_completely_stopped():
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


static func get_required_dice_slots(ability: AbilityDefinition) -> int:
	var total_required := 0
	for dice_condition in build_slot_conditions(ability):
		if dice_condition == null:
			continue
		total_required += 1
	return total_required


static func monster_has_usable_ability(abilities: Array[AbilityDefinition], dice_list: Array[Dice]) -> bool:
	for ability in abilities:
		if ability == null:
			continue
		if can_use_ability_with_dice(ability, dice_list):
			return true
	return false


static func _find_matching_dice_for_condition(
	condition: AbilityDiceCondition,
	ability: AbilityDefinition,
	available_dice: Array[Dice],
	used_dice: Dictionary
) -> Dice:
	for dice in available_dice:
		if used_dice.has(dice.get_instance_id()):
			continue
		if not dice_matches_slot(dice, condition, ability):
			continue
		return dice
	return null


static func _matches_owner(dice: Dice, owner: StringName, monster_index: int) -> bool:
	if dice == null:
		return false
	var metadata := dice.get_runtime_metadata()
	if StringName(metadata.get("owner", &"")) != owner:
		return false
	if owner == &"monster":
		return int(metadata.get("monster_index", -1)) == monster_index
	return true
