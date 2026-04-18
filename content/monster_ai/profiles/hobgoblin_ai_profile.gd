extends MonsterAiProfile
class_name HobgoblinAiProfile

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")

const ABILITY_HOBGOBLIN_CLUB_STRIKE := "hobgoblin_club_strike"
const ABILITY_HOBGOBLIN_RAGE := "hobgoblin_rage"
const TARGET_PLAYER := {"kind": &"player"}


func decide_next_action(monster_index: int, battle_room, available_dice: Array[Dice]) -> MonsterAiDecision:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		_log_debug("hobgoblin turn finished: monster_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_missing")
	if not battle_room.can_target_player():
		_log_debug("hobgoblin turn finished: player_unavailable index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"player_unavailable")

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		_log_debug("hobgoblin turn finished: monster_view_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_view_missing")

	var owner_status_container = battle_room.get_status_container_for_descriptor({"kind": &"monster", "index": monster_index})

	var club_strike_ability := _find_ability_by_id(monster_view.abilities, ABILITY_HOBGOBLIN_CLUB_STRIKE)
	if club_strike_ability != null and BattleAbilityRuntime.can_use_ability_with_dice(club_strike_ability, available_dice, true, owner_status_container):
		_log_debug("hobgoblin chose club_strike (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(club_strike_ability, TARGET_PLAYER, &"hobgoblin_club_strike_priority")

	var hobgoblin_rage_ability := _find_ability_by_id(monster_view.abilities, ABILITY_HOBGOBLIN_RAGE)
	if hobgoblin_rage_ability != null and BattleAbilityRuntime.can_use_ability_with_dice(hobgoblin_rage_ability, available_dice, true, owner_status_container):
		var target_self := _build_target_self(monster_index)
		_log_debug("hobgoblin chose rage (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(hobgoblin_rage_ability, target_self, &"hobgoblin_rage_fallback")

	_log_debug("hobgoblin ends turn: no usable abilities (monster=%s, index=%d, ready_dice=%d)" % [String(monster_view.combatant_id), monster_index, available_dice.size()])
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
	print("[Debug][MonsterAI][Hobgoblin] %s" % message)
