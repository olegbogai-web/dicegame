extends MonsterAiProfile
class_name ChimeraAiProfile

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")

const ABILITY_STRENGTHENING := "strengthening"
const ABILITY_CLAWED_SERIES := "clawed_series"
const TARGET_PLAYER := {"kind": &"player"}

var _strengthening_used_turn_keys: Dictionary = {}


func decide_next_action(monster_index: int, battle_room, available_dice: Array[Dice]) -> MonsterAiDecision:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		return MonsterAiDecision.end_turn(&"monster_missing")
	if not battle_room.can_target_player():
		return MonsterAiDecision.end_turn(&"player_unavailable")

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		return MonsterAiDecision.end_turn(&"monster_view_missing")

	var strengthening_turn_key := _build_strengthening_turn_key(battle_room, monster_view.combatant_id)
	var strengthening_ability := _find_ability_by_id(monster_view.abilities, ABILITY_STRENGTHENING)
	if not _strengthening_used_turn_keys.has(strengthening_turn_key) and _can_use_strengthening_with_any_three_dice(strengthening_ability, available_dice):
		_strengthening_used_turn_keys[strengthening_turn_key] = true
		return MonsterAiDecision.use_ability(strengthening_ability, {"kind": &"monster", "index": monster_index}, &"strengthening_priority")

	var clawed_series_ability := _find_ability_by_id(monster_view.abilities, ABILITY_CLAWED_SERIES)
	if clawed_series_ability != null and BattleAbilityRuntime.can_use_ability_with_dice(clawed_series_ability, available_dice, true):
		return MonsterAiDecision.use_ability(clawed_series_ability, TARGET_PLAYER, &"clawed_series_priority")

	return MonsterAiDecision.end_turn(&"no_priority_abilities")


func _build_strengthening_turn_key(battle_room, combatant_id: StringName) -> String:
	var turn_counter := int(battle_room.turn_counter if battle_room != null else 0)
	return "%s:%d" % [String(combatant_id), turn_counter]


func _find_ability_by_id(abilities: Array[AbilityDefinition], ability_id: String) -> AbilityDefinition:
	for ability in abilities:
		if ability == null:
			continue
		if ability.ability_id == ability_id:
			return ability
	return null


func _can_use_strengthening_with_any_three_dice(ability: AbilityDefinition, available_dice: Array[Dice]) -> bool:
	if ability == null:
		return false
	var ready_dice := BattleAbilityRuntime.filter_ready_dice(available_dice, true)
	if ready_dice.size() < 3:
		return false
	var values: Array[int] = []
	for dice in ready_dice:
		values.append(maxi(dice.get_top_face_value(), 0))
	values.sort()
	var left := 0
	var right := values.size() - 1
	while left < right - 1:
		var pair_target := 9 - values[left]
		var inner_left := left + 1
		var inner_right := right
		while inner_left < inner_right:
			var pair_sum := values[inner_left] + values[inner_right]
			if pair_sum == pair_target:
				return BattleAbilityRuntime.can_use_ability_with_dice(ability, ready_dice, true)
			if pair_sum < pair_target:
				inner_left += 1
			else:
				inner_right -= 1
		left += 1
	return false
