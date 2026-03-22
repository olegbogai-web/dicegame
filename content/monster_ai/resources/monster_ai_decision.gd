extends RefCounted
class_name MonsterAiDecision

var decision_type: StringName = &"end_turn"
var ability: AbilityDefinition
var target_descriptor: Dictionary = {}
var reason: StringName = &""


static func use_ability(next_ability: AbilityDefinition, next_target_descriptor: Dictionary, next_reason: StringName = &"use_ability") -> MonsterAiDecision:
	var decision := MonsterAiDecision.new()
	decision.decision_type = &"use_ability"
	decision.ability = next_ability
	decision.target_descriptor = next_target_descriptor.duplicate(true)
	decision.reason = next_reason
	return decision


static func end_turn(next_reason: StringName = &"ai_signal") -> MonsterAiDecision:
	var decision := MonsterAiDecision.new()
	decision.decision_type = &"end_turn"
	decision.reason = next_reason
	return decision


func is_end_turn() -> bool:
	return decision_type == &"end_turn"
