extends MonsterAiProfile
class_name TestMonsterAiProfile

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")


func decide_next_action(monster_index: int, battle_room, available_dice: Array[Dice]) -> MonsterAiDecision:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		return MonsterAiDecision.end_turn(&"monster_missing")
	if not battle_room.can_target_player():
		return MonsterAiDecision.end_turn(&"player_unavailable")

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		return MonsterAiDecision.end_turn(&"monster_view_missing")
	var owner_status_container = battle_room.get_status_container_for_descriptor({"kind": &"monster", "index": monster_index})

	for ability in monster_view.abilities:
		if ability == null:
			continue
		if ability.ability_id != "common_attack":
			continue
		if BattleAbilityRuntime.can_use_ability_with_dice(ability, available_dice, true, owner_status_container):
			return MonsterAiDecision.use_ability(ability, {"kind": &"player"}, &"common_attack")

	return MonsterAiDecision.end_turn(&"common_attack_unavailable")
