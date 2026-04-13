extends MonsterAiProfile
class_name TurtleAiProfile

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")

const ABILITY_TURTLE_DURABILITY := "turtle_durability"
const ABILITY_TURTLE_DEFENSE := "turtle_defense"
const ABILITY_TURTLE_BITE := "turtle_bite"
const TARGET_PLAYER := {"kind": &"player"}


func decide_next_action(monster_index: int, battle_room, available_dice: Array[Dice]) -> MonsterAiDecision:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		_log_debug("turtle turn finished: monster_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_missing")
	if not battle_room.can_target_player():
		_log_debug("turtle turn finished: player_unavailable index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"player_unavailable")

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		_log_debug("turtle turn finished: monster_view_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_view_missing")

	var turtle_durability := _find_ability_by_id(monster_view.abilities, ABILITY_TURTLE_DURABILITY)
	if turtle_durability != null and BattleAbilityRuntime.can_use_ability_with_dice(turtle_durability, available_dice, true):
		var target_self_durability := _build_target_self(monster_index)
		_log_debug("turtle chose turtle_durability (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(turtle_durability, target_self_durability, &"turtle_durability_priority")

	var turtle_defense := _find_ability_by_id(monster_view.abilities, ABILITY_TURTLE_DEFENSE)
	if turtle_defense != null and BattleAbilityRuntime.can_use_ability_with_dice(turtle_defense, available_dice, true):
		var target_self_defense := _build_target_self(monster_index)
		_log_debug("turtle chose turtle_defense (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(turtle_defense, target_self_defense, &"turtle_defense_fallback")

	var turtle_bite := _find_ability_by_id(monster_view.abilities, ABILITY_TURTLE_BITE)
	if turtle_bite != null and BattleAbilityRuntime.can_use_ability_with_dice(turtle_bite, available_dice, true):
		_log_debug("turtle chose turtle_bite (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(turtle_bite, TARGET_PLAYER, &"turtle_bite_fallback")

	_log_debug("turtle ends turn: no usable abilities (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
	return MonsterAiDecision.end_turn(&"no_priority_abilities")


func _build_target_self(monster_index: int) -> Dictionary:
	return {"kind": &"monster", "index": monster_index}


func _find_ability_by_id(abilities: Array[AbilityDefinition], ability_id: String) -> AbilityDefinition:
	for ability in abilities:
		if ability == null:
			continue
		if ability.ability_id == ability_id:
			return ability
	return null


func _log_debug(message: String) -> void:
	print("[Debug][MonsterAI][Turtle] %s" % message)
