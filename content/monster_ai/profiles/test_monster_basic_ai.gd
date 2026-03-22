extends MonsterAIProfile
class_name TestMonsterBasicAI

const BattleDiceRules = preload("res://content/combat/runtime/battle_dice_rules.gd")


func decide_next_action(battle_room: BattleRoom, monster_index: int, dice_list: Array) -> Dictionary:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		return {
			"kind": &"end_turn",
			"reason": &"monster_missing",
		}

	var common_attack := battle_room.find_monster_ability_by_id(monster_index, &"common_attack")
	if common_attack != null and BattleDiceRules.can_use_ability_with_dice(common_attack, dice_list):
		return {
			"kind": &"use_ability",
			"reason": &"use_common_attack",
			"ability": common_attack,
			"target": {
				"kind": &"player",
			},
			"dice_assignments": BattleDiceRules.build_dice_assignments_for_ability(common_attack, dice_list),
		}

	return {
		"kind": &"end_turn",
		"reason": &"common_attack_unavailable",
	}
