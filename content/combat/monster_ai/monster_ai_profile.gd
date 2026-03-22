extends RefCounted
class_name MonsterAiProfile


func decide_next_action(_context: Dictionary) -> MonsterAiAction:
	return MonsterAiAction.create_end_turn("base_profile_default")
