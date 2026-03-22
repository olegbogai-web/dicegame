extends MonsterAiProfile
class_name TestMonsterAiProfile

const COMMON_ATTACK_ABILITY_ID := &"common_attack"


func decide_next_action(context: Dictionary) -> MonsterAiAction:
	var available_actions: Array = context.get("available_actions", [])
	for action in available_actions:
		if not (action is MonsterAiAction):
			continue
		if action.ability != null and action.ability.ability_id == COMMON_ATTACK_ABILITY_ID:
			action.debug_reason = "test_monster_prefers_common_attack"
			return action
	return MonsterAiAction.create_end_turn("test_monster_no_common_attack")
