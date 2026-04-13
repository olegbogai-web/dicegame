extends MonsterAiProfile
class_name GoblinAiProfile

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")

const ABILITY_POISON_STRIKE := "goblin_poison_strike"
const ABILITY_INFLICT_POISON := "goblin_inflict_poison"
const TARGET_PLAYER := {"kind": &"player"}
const TARGET_SELF := {"kind": &"monster", "index": -1}


func decide_next_action(monster_index: int, battle_room, available_dice: Array[Dice], dice_value_penalty: int = 0) -> MonsterAiDecision:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		_log_debug("goblin turn finished: monster_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_missing")
	if not battle_room.can_target_player():
		_log_debug("goblin turn finished: player_unavailable index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"player_unavailable")

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		_log_debug("goblin turn finished: monster_view_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_view_missing")

	var poison_strike_ability := _find_ability_by_id(monster_view.abilities, ABILITY_POISON_STRIKE)
	if poison_strike_ability != null and BattleAbilityRuntime.can_use_ability_with_dice(poison_strike_ability, available_dice, true, dice_value_penalty):
		_log_debug("goblin chose poison_strike (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(poison_strike_ability, TARGET_PLAYER, &"goblin_poison_strike_priority")

	var inflict_poison_ability := _find_ability_by_id(monster_view.abilities, ABILITY_INFLICT_POISON)
	if inflict_poison_ability != null and BattleAbilityRuntime.can_use_ability_with_dice(inflict_poison_ability, available_dice, true, dice_value_penalty):
		var target_self := TARGET_SELF.duplicate()
		target_self["index"] = monster_index
		_log_debug("goblin chose inflict_poison (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(inflict_poison_ability, target_self, &"goblin_inflict_poison_fallback")

	_log_debug("goblin ends turn: no usable abilities (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
	return MonsterAiDecision.end_turn(&"no_priority_abilities")


func _find_ability_by_id(abilities: Array[AbilityDefinition], ability_id: String) -> AbilityDefinition:
	for ability in abilities:
		if ability == null:
			continue
		if ability.ability_id == ability_id:
			return ability
	return null


func _log_debug(message: String) -> void:
	print("[Debug][MonsterAI][Goblin] %s" % message)
