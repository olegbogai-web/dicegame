@tool
extends MonsterAiProfile
class_name TestMonsterAiProfile

const COMMON_ATTACK_ABILITY_ID := &"common_attack"


func decide_next_action(decision_context: Dictionary) -> Dictionary:
	var usable_abilities: Array = decision_context.get("usable_abilities", [])
	for usable_entry in usable_abilities:
		var ability := usable_entry.get("ability") as AbilityDefinition
		if ability == null or ability.ability_id != COMMON_ATTACK_ABILITY_ID:
			continue
		if not bool(decision_context.get("can_target_player", false)):
			break
		var consumed_dice: Array[Dice] = []
		for dice in usable_entry.get("consumed_dice", []):
			if dice is Dice:
				consumed_dice.append(dice)
		return MonsterAiProfile.create_use_ability_decision(
			ability,
			consumed_dice,
			{"kind": &"player"},
			&"test_monster_common_attack"
		)

	return MonsterAiProfile.create_end_turn_decision(&"common_attack_unavailable")
