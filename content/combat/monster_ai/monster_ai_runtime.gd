extends RefCounted
class_name MonsterAiRuntime

const AbilityRuntimeScript = preload("res://content/combat/ability_runtime.gd")
const MonsterAiRegistryScript = preload("res://content/combat/monster_ai/monster_ai_registry.gd")
const MonsterAiActionScript = preload("res://content/combat/monster_ai/monster_ai_action.gd")

const OWNER_META_KEY := &"owner"
const MONSTER_INDEX_META_KEY := &"monster_index"


static func are_monster_turn_dice_settled(dice_list: Array[Dice], monster_index: int) -> bool:
	for dice in dice_list:
		if not _is_monster_turn_die(dice, monster_index):
			continue
		if not dice.sleeping or dice.is_being_dragged():
			return false
	return true


static func decide_next_action(battle_room: BattleRoom, monster_index: int, dice_list: Array[Dice]) -> MonsterAiAction:
	if battle_room == null or not battle_room.is_monster_turn() or battle_room.current_monster_turn_index != monster_index:
		return MonsterAiActionScript.create_end_turn("monster_turn_inactive")

	var monster_definition := battle_room.get_monster_definition(monster_index)
	var profile := MonsterAiRegistryScript.resolve_profile(monster_definition)
	var available_actions := build_available_actions(battle_room, monster_index, dice_list)
	if profile == null:
		return MonsterAiActionScript.create_end_turn("missing_monster_ai_profile")
	var context := {
		"battle_room": battle_room,
		"monster_index": monster_index,
		"monster_definition": monster_definition,
		"available_actions": available_actions,
	}
	var action := profile.decide_next_action(context)
	if action == null:
		return MonsterAiActionScript.create_end_turn("monster_ai_returned_null")
	return action


static func build_available_actions(battle_room: BattleRoom, monster_index: int, dice_list: Array[Dice]) -> Array[MonsterAiAction]:
	var available_actions: Array[MonsterAiAction] = []
	var usable_dice := get_stopped_monster_dice(dice_list, monster_index)
	for ability in battle_room.get_monster_abilities_for_index(monster_index):
		if ability == null:
			continue
		var target_descriptor := _resolve_default_target_descriptor(battle_room, monster_index, ability)
		if target_descriptor.is_empty():
			continue
		var consumed_dice := []
		if ability.cost != null and ability.cost.requires_dice():
			consumed_dice = AbilityRuntimeScript.find_payment_dice(ability, usable_dice)
			if consumed_dice.is_empty():
				continue
		available_actions.append(
			MonsterAiActionScript.create_use_ability(
				ability,
				consumed_dice,
				target_descriptor,
				"ability_is_payable"
			)
		)
	return available_actions


static func get_stopped_monster_dice(dice_list: Array[Dice], monster_index: int) -> Array[Dice]:
	var resolved: Array[Dice] = []
	for dice in dice_list:
		if not _is_monster_turn_die(dice, monster_index):
			continue
		if not dice.sleeping or dice.is_being_dragged():
			continue
		resolved.append(dice)
	return resolved


static func _is_monster_turn_die(dice: Dice, monster_index: int) -> bool:
	if dice == null:
		return false
	var owner := String(dice.get_meta(OWNER_META_KEY, &""))
	if owner != "monster":
		return false
	return int(dice.get_meta(MONSTER_INDEX_META_KEY, -1)) == monster_index


static func _resolve_default_target_descriptor(battle_room: BattleRoom, monster_index: int, ability: AbilityDefinition) -> Dictionary:
	if battle_room == null or ability == null or ability.target_rule == null:
		return {}
	match ability.target_rule.get_target_hint():
		&"single_enemy":
			if battle_room.can_target_player():
				return {"kind": &"player"}
		&"all_enemies", &"global":
			if battle_room.can_target_player():
				return {"kind": &"player"}
		&"self":
			if battle_room.can_target_monster(monster_index):
				return {"kind": &"monster", "index": monster_index}
	return {}
