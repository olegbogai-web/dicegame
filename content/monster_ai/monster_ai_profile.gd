extends RefCounted
class_name MonsterAIProfile


func decide_next_action(_battle_room: BattleRoom, _monster_index: int, _dice_list: Array) -> Dictionary:
	return {
		"kind": &"end_turn",
		"reason": &"no_ai_rule",
	}
