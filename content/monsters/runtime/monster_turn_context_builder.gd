extends RefCounted
class_name MonsterTurnContextBuilder

const AbilitySlotRulesScript = preload("res://content/combat/ability_slot_rules.gd")


static func build_context(
	battle_room: BattleRoom,
	monster_index: int,
	frame_states: Array[Dictionary],
	dice_list: Array[Dice]
) -> Dictionary:
	var available_actions: Array[Dictionary] = []
	var fully_stopped_dice_count := 0
	for dice in dice_list:
		if dice != null and dice.is_fully_stopped():
			fully_stopped_dice_count += 1

	if battle_room == null or not battle_room.can_target_monster(monster_index):
		return {
			"monster_index": monster_index,
			"available_actions": available_actions,
			"remaining_dice_count": dice_list.size(),
			"fully_stopped_dice_count": fully_stopped_dice_count,
		}

	for frame_state in frame_states:
		if int(frame_state.get("monster_index", -1)) != monster_index:
			continue
		var ability := frame_state.get("ability") as AbilityDefinition
		if ability == null:
			continue
		var ready_dice := AbilitySlotRulesScript.collect_ready_dice_for_ability(ability, dice_list, true)
		var required_dice_count := battle_room.get_required_dice_slots(ability)
		if required_dice_count > 0 and ready_dice.is_empty():
			continue
		available_actions.append({
			"ability": ability,
			"ability_id": ability.ability_id,
			"ability_index": int(frame_state.get("ability_index", -1)),
			"frame_state": frame_state,
			"dice": ready_dice,
			"target_descriptor": _build_default_target_descriptor(ability, battle_room, monster_index),
		})

	return {
		"monster_id": battle_room.get_monster_id(monster_index),
		"monster_index": monster_index,
		"available_actions": available_actions,
		"remaining_dice_count": dice_list.size(),
		"fully_stopped_dice_count": fully_stopped_dice_count,
	}


static func _build_default_target_descriptor(
	ability: AbilityDefinition,
	battle_room: BattleRoom,
	monster_index: int
) -> Dictionary:
	if ability == null or ability.target_rule == null:
		return {}

	match ability.target_rule.get_target_hint():
		&"self":
			return {
				"kind": &"monster",
				"index": monster_index,
			}
		&"single_enemy":
			if battle_room.can_target_player():
				return {
					"kind": &"player",
				}
		&"all_enemies", &"global":
			if battle_room.can_target_player():
				return {
					"kind": &"player",
				}
	return {}
