extends MonsterAiProfile
class_name RatAiProfile

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")

const ABILITY_RAT_BITE := "rat_bite"
const TARGET_PLAYER := {"kind": &"player"}


func decide_next_action(monster_index: int, battle_room, available_dice: Array[Dice]) -> MonsterAiDecision:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		_log_debug("rat turn finished: monster_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_missing")
	if not battle_room.can_target_player():
		_log_debug("rat turn finished: player_unavailable index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"player_unavailable")

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		_log_debug("rat turn finished: monster_view_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_view_missing")

	var owner_status_container = battle_room.get_status_container_for_descriptor({"kind": &"monster", "index": monster_index})

	var rat_bite_ability := _find_ability_by_id(monster_view.abilities, ABILITY_RAT_BITE)
	if rat_bite_ability != null and BattleAbilityRuntime.can_use_ability_with_dice(rat_bite_ability, available_dice, true, owner_status_container):
		_log_debug("rat chose rat_bite (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(rat_bite_ability, TARGET_PLAYER, &"rat_bite_priority")

	_log_debug("rat ends turn: rat_bite_unavailable (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
	return MonsterAiDecision.end_turn(&"rat_bite_unavailable")


func _find_ability_by_id(abilities: Array[AbilityDefinition], ability_id: String) -> AbilityDefinition:
	for ability in abilities:
		if ability == null:
			continue
		if ability.ability_id == ability_id:
			return ability
	return null


func _log_debug(message: String) -> void:
	print("[Debug][MonsterAI][Rat] %s" % message)
