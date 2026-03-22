extends BaseMonsterAi
class_name TestMonsterAi

const COMMON_ATTACK_ID := &"common_attack"


func decide_next_action(context: Dictionary) -> Dictionary:
	var available_actions: Array = context.get("available_actions", [])
	for action in available_actions:
		if StringName(action.get("ability_id", &"")) != COMMON_ATTACK_ID:
			continue
		return {
			"type": ACTION_USE_ABILITY,
			"action": action,
		}

	return {
		"type": ACTION_END_TURN,
	}
