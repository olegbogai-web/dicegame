extends RefCounted
class_name MonsterAiDecisionService

const AbilityDiceMatcherScript = preload("res://content/abilities/runtime/ability_dice_matcher.gd")

var _dice_matcher := AbilityDiceMatcherScript.new()


func build_decision_context(
	battle_room: BattleRoom,
	monster_definition: MonsterDefinition,
	monster_index: int,
	board_dice: Array[Dice]
) -> Dictionary:
	var stationary_dice := _collect_stationary_dice(board_dice)
	return {
		"battle_room": battle_room,
		"monster_definition": monster_definition,
		"monster_index": monster_index,
		"available_dice": stationary_dice,
		"can_target_player": battle_room != null and battle_room.can_target_player(),
		"usable_abilities": _build_usable_abilities(monster_definition, stationary_dice),
	}


func decide_next_action(
	battle_room: BattleRoom,
	monster_definition: MonsterDefinition,
	monster_index: int,
	board_dice: Array[Dice]
) -> Dictionary:
	if monster_definition == null or monster_definition.ai_profile == null:
		return MonsterAiProfile.create_end_turn_decision(&"missing_ai_profile")
	var decision_context := build_decision_context(battle_room, monster_definition, monster_index, board_dice)
	return monster_definition.ai_profile.decide_next_action(decision_context)


func collect_monster_dice(board_dice: Array[Dice], monster_index: int) -> Array[Dice]:
	var monster_dice: Array[Dice] = []
	for dice in board_dice:
		if dice == null or not is_instance_valid(dice):
			continue
		var owner := String(dice.get_runtime_metadata_value("owner", ""))
		var owner_monster_index := int(dice.get_runtime_metadata_value("monster_index", -1))
		if owner == "monster" and owner_monster_index == monster_index:
			monster_dice.append(dice)
	return monster_dice


func has_moving_dice(board_dice: Array[Dice], monster_index: int) -> bool:
	for dice in collect_monster_dice(board_dice, monster_index):
		if not _is_die_stationary(dice):
			return true
	return false


func _build_usable_abilities(monster_definition: MonsterDefinition, stationary_dice: Array[Dice]) -> Array[Dictionary]:
	var usable_abilities: Array[Dictionary] = []
	if monster_definition == null:
		return usable_abilities

	for ability_index in monster_definition.abilities.size():
		var ability := monster_definition.abilities[ability_index]
		if ability == null:
			continue
		var consumed_dice := _dice_matcher.find_matching_dice(ability, stationary_dice)
		if ability.cost != null and ability.cost.requires_dice() and consumed_dice.is_empty():
			continue
		usable_abilities.append({
			"ability": ability,
			"ability_index": ability_index,
			"consumed_dice": consumed_dice,
		})
	return usable_abilities


func _collect_stationary_dice(board_dice: Array[Dice]) -> Array[Dice]:
	var stationary_dice: Array[Dice] = []
	for dice in board_dice:
		if _is_die_stationary(dice):
			stationary_dice.append(dice)
	return stationary_dice


func _is_die_stationary(dice: Dice) -> bool:
	return (
		dice != null
		and is_instance_valid(dice)
		and dice.sleeping
		and not dice.is_being_dragged()
		and dice.linear_velocity.length_squared() <= 0.0001
		and dice.angular_velocity.length_squared() <= 0.0001
	)
