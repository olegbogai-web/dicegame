@tool
extends Resource
class_name MonsterAiProfile


func decide_next_action(decision_context: Dictionary) -> Dictionary:
	return create_end_turn_decision(&"no_monster_ai_rule")


static func create_use_ability_decision(
	ability: AbilityDefinition,
	consumed_dice: Array[Dice],
	target_descriptor: Dictionary,
	reason: StringName = &"ability_selected"
) -> Dictionary:
	return {
		"kind": &"use_ability",
		"ability": ability,
		"consumed_dice": consumed_dice,
		"target_descriptor": target_descriptor.duplicate(true),
		"reason": reason,
	}


static func create_end_turn_decision(reason: StringName) -> Dictionary:
	return {
		"kind": &"end_turn",
		"reason": reason,
	}
