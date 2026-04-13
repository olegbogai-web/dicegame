extends Resource
class_name MonsterAiProfile

func decide_next_action(_monster_index: int, _battle_room, _available_dice: Array[Dice], _dice_value_penalty: int = 0) -> MonsterAiDecision:
	return MonsterAiDecision.end_turn(&"missing_profile")
