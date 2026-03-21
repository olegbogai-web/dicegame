extends RefCounted
class_name TurnDicePool

const TurnDie = preload("res://content/combat/runtime/turn_die.gd")
const AbilityDiceCondition = preload("res://content/abilities/resources/ability_dice_condition.gd")

var rolled: Array[TurnDie] = []
var available: Array[TurnDie] = []
var slotted: Dictionary = {}
var spent: Array[TurnDie] = []
var consumed_until_next_turn: Array[TurnDie] = []
var locked: Array[TurnDie] = []


func set_rolled_dice(dice: Array[TurnDie]) -> void:
	rolled = dice.duplicate()
	available = dice.duplicate()
	slotted.clear()
	spent.clear()
	consumed_until_next_turn.clear()
	locked.clear()


func get_available_dice() -> Array[TurnDie]:
	return available.duplicate()


func has_available_dice() -> bool:
	return not available.is_empty()


func get_die_by_id(die_id: String) -> TurnDie:
	for die in rolled:
		if die != null and die.die_id == die_id:
			return die
	return null


func clear_slots() -> void:
	slotted.clear()


func slot_dice(condition_index: int, dice_ids: Array[String]) -> bool:
	var selected: Array[TurnDie] = []
	for die_id in dice_ids:
		var die := _extract_available_die(die_id)
		if die == null:
			_restore_available(selected)
			return false
		selected.append(die)
	slotted[condition_index] = selected
	return true


func get_slotted_dice(condition_index: int) -> Array[TurnDie]:
	var selected: Array[TurnDie] = []
	var source = slotted.get(condition_index, [])
	for die in source:
		if die != null:
			selected.append(die)
	return selected


func can_pay_cost(dice_conditions: Array[AbilityDiceCondition], provided_ids: Array[String]) -> bool:
	return not build_cost_selection(dice_conditions, provided_ids).is_empty() or dice_conditions.is_empty()


func build_cost_selection(dice_conditions: Array[AbilityDiceCondition], provided_ids: Array[String]) -> Dictionary:
	if dice_conditions.is_empty():
		return {}
	var provided_dice: Array[TurnDie] = []
	for die_id in provided_ids:
		var die := _find_available_die(die_id)
		if die == null:
			return {}
		provided_dice.append(die)

	var remaining := provided_dice.duplicate()
	var selection := {}
	for index in dice_conditions.size():
		var condition: AbilityDiceCondition = dice_conditions[index]
		if condition == null:
			return {}
		var matched := _select_for_condition(condition, remaining)
		if matched.is_empty() and condition.required_count > 0:
			return {}
		selection[index] = matched
		for die in matched:
			remaining.erase(die)

	if remaining.size() > 0:
		return {}
	return selection


func spend_selection(selection: Dictionary, dice_conditions: Array[AbilityDiceCondition]) -> Array[TurnDie]:
	var committed: Array[TurnDie] = []
	for key in selection.keys():
		var condition_index: int = int(key)
		var condition: AbilityDiceCondition = dice_conditions[condition_index]
		var selected: Array = selection[key]
		for die_value in selected:
			var die := die_value as TurnDie
			if die == null:
				continue
			var extracted := _extract_available_die(die.die_id)
			if extracted == null:
				continue
			committed.append(extracted)
			spent.append(extracted)
			if condition == null or condition.consume_on_use:
				consumed_until_next_turn.append(extracted)
	slotted.clear()
	return committed


func auto_select_cost(dice_conditions: Array[AbilityDiceCondition]) -> Dictionary:
	var working := available.duplicate()
	var selection := {}
	for index in dice_conditions.size():
		var condition: AbilityDiceCondition = dice_conditions[index]
		if condition == null:
			return {}
		var matched := _select_for_condition(condition, working)
		if matched.is_empty() and condition.required_count > 0:
			return {}
		selection[index] = matched
		for die in matched:
			working.erase(die)
	return selection


func _select_for_condition(condition: AbilityDiceCondition, source: Array[TurnDie]) -> Array[TurnDie]:
	var matched: Array[TurnDie] = []
	for die in source:
		if die == null or not _matches_condition(die, condition):
			continue
		matched.append(die)
		if matched.size() >= condition.required_count:
			break
	if matched.size() < condition.required_count:
		return []
	if condition.requires_same_value and not _all_same_value(matched):
		return []
	if condition.requires_unique_values and not _all_unique_values(matched):
		return []
	return matched


func _matches_condition(die: TurnDie, condition: AbilityDiceCondition) -> bool:
	if not condition.matches_value(die.value):
		return false
	if condition.requires_face_filter() and not condition.accepted_face_ids.has(die.face_id):
		return false
	for required_tag in condition.required_tags:
		if not die.tags.has(required_tag):
			return false
	for forbidden_tag in condition.forbidden_tags:
		if die.tags.has(forbidden_tag):
			return false
	return true


func _all_same_value(dice: Array[TurnDie]) -> bool:
	if dice.is_empty():
		return true
	var first_value := dice[0].value
	for die in dice:
		if die.value != first_value:
			return false
	return true


func _all_unique_values(dice: Array[TurnDie]) -> bool:
	var seen := {}
	for die in dice:
		if seen.has(die.value):
			return false
		seen[die.value] = true
	return true


func _find_available_die(die_id: String) -> TurnDie:
	for die in available:
		if die != null and die.die_id == die_id:
			return die
	return null


func _extract_available_die(die_id: String) -> TurnDie:
	for index in available.size():
		var die: TurnDie = available[index]
		if die != null and die.die_id == die_id:
			available.remove_at(index)
			return die
	return null


func _restore_available(dice: Array[TurnDie]) -> void:
	for die in dice:
		if die != null:
			available.append(die)
