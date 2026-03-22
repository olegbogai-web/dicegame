extends RefCounted
class_name BaseMonsterAi

const ACTION_WAIT := &"wait"
const ACTION_USE_ABILITY := &"use_ability"
const ACTION_END_TURN := &"end_turn"


func decide_next_action(_context: Dictionary) -> Dictionary:
	return {
		"type": ACTION_END_TURN,
	}
