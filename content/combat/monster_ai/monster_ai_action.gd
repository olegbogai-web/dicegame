extends RefCounted
class_name MonsterAiAction

const TYPE_USE_ABILITY := &"use_ability"
const TYPE_END_TURN := &"end_turn"

var action_type: StringName = TYPE_END_TURN
var ability: AbilityDefinition
var consumed_dice: Array[Dice] = []
var target_descriptor: Dictionary = {}
var debug_reason := ""


static func create_end_turn(reason: String = "") -> MonsterAiAction:
	var action := MonsterAiAction.new()
	action.action_type = TYPE_END_TURN
	action.debug_reason = reason
	return action


static func create_use_ability(
	next_ability: AbilityDefinition,
	next_consumed_dice: Array[Dice],
	next_target_descriptor: Dictionary,
	reason: String = ""
) -> MonsterAiAction:
	var action := MonsterAiAction.new()
	action.action_type = TYPE_USE_ABILITY
	action.ability = next_ability
	action.consumed_dice = next_consumed_dice.duplicate()
	action.target_descriptor = next_target_descriptor.duplicate(true)
	action.debug_reason = reason
	return action


func is_end_turn() -> bool:
	return action_type == TYPE_END_TURN


func is_use_ability() -> bool:
	return action_type == TYPE_USE_ABILITY and ability != null
