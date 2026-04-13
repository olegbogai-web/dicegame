extends MonsterAiProfile
class_name GoblinShamanAiProfile

const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")

const ABILITY_SHAMAN_CURSE := "goblin_shaman_curse"
const ABILITY_POISONOUS_MIASMA := "goblin_shaman_poisonous_miasma"
const ABILITY_RESTORATION_MAGIC := "goblin_shaman_restoration_magic"
const HEALING_PRIORITY_HP_THRESHOLD := 60
const TARGET_PLAYER := {"kind": &"player"}
const TARGET_SELF := {"kind": &"monster", "index": -1}


func decide_next_action(monster_index: int, battle_room, available_dice: Array[Dice], dice_value_penalty: int = 0) -> MonsterAiDecision:
	if battle_room == null or not battle_room.can_target_monster(monster_index):
		_log_debug("goblin_shaman turn finished: monster_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_missing")
	if not battle_room.can_target_player():
		_log_debug("goblin_shaman turn finished: player_unavailable index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"player_unavailable")

	var monster_view = battle_room.get_monster_view(monster_index)
	if monster_view == null:
		_log_debug("goblin_shaman turn finished: monster_view_missing index=%d" % monster_index)
		return MonsterAiDecision.end_turn(&"monster_view_missing")

	var is_low_hp = monster_view.current_hp <= HEALING_PRIORITY_HP_THRESHOLD
	if is_low_hp:
		return _decide_low_hp_action(monster_index, monster_view.abilities, available_dice, dice_value_penalty)
	return _decide_high_hp_action(monster_index, monster_view.abilities, available_dice, dice_value_penalty)


func _decide_high_hp_action(monster_index: int, abilities: Array[AbilityDefinition], available_dice: Array[Dice], dice_value_penalty: int) -> MonsterAiDecision:
	var curse_ability := _find_ability_by_id(abilities, ABILITY_SHAMAN_CURSE)
	if _can_use_ability(curse_ability, available_dice, dice_value_penalty):
		_log_debug("goblin_shaman chose curse (hp>60, index=%d, ready_dice=%d)" % [monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(curse_ability, TARGET_PLAYER, &"goblin_shaman_high_hp_curse_priority")

	var miasma_ability := _find_ability_by_id(abilities, ABILITY_POISONOUS_MIASMA)
	if _can_use_ability(miasma_ability, available_dice, dice_value_penalty):
		var target_self := _build_target_self(monster_index)
		_log_debug("goblin_shaman chose miasma (hp>60, index=%d, ready_dice=%d)" % [monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(miasma_ability, target_self, &"goblin_shaman_high_hp_miasma_fallback")

	var restoration_ability := _find_ability_by_id(abilities, ABILITY_RESTORATION_MAGIC)
	if _can_use_ability(restoration_ability, available_dice, dice_value_penalty):
		var target_self := _build_target_self(monster_index)
		_log_debug("goblin_shaman chose restoration (hp>60, index=%d, ready_dice=%d)" % [monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(restoration_ability, target_self, &"goblin_shaman_high_hp_restoration_fallback")

	_log_debug("goblin_shaman ends turn: no usable abilities (hp>60, index=%d, ready_dice=%d)" % [monster_index, available_dice.size()])
	return MonsterAiDecision.end_turn(&"no_priority_abilities")


func _decide_low_hp_action(monster_index: int, abilities: Array[AbilityDefinition], available_dice: Array[Dice], dice_value_penalty: int) -> MonsterAiDecision:
	var restoration_ability := _find_ability_by_id(abilities, ABILITY_RESTORATION_MAGIC)
	if _can_use_ability(restoration_ability, available_dice, dice_value_penalty):
		var target_self := _build_target_self(monster_index)
		_log_debug("goblin_shaman chose restoration (hp<=60, index=%d, ready_dice=%d)" % [monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(restoration_ability, target_self, &"goblin_shaman_low_hp_restoration_priority")

	var curse_ability := _find_ability_by_id(abilities, ABILITY_SHAMAN_CURSE)
	if _can_use_ability(curse_ability, available_dice, dice_value_penalty):
		_log_debug("goblin_shaman chose curse (hp<=60, index=%d, ready_dice=%d)" % [monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(curse_ability, TARGET_PLAYER, &"goblin_shaman_low_hp_curse_fallback")

	var miasma_ability := _find_ability_by_id(abilities, ABILITY_POISONOUS_MIASMA)
	if _can_use_ability(miasma_ability, available_dice, dice_value_penalty):
		var target_self := _build_target_self(monster_index)
		_log_debug("goblin_shaman chose miasma (hp<=60, index=%d, ready_dice=%d)" % [monster_index, available_dice.size()])
		return MonsterAiDecision.use_ability(miasma_ability, target_self, &"goblin_shaman_low_hp_miasma_fallback")

	_log_debug("goblin_shaman ends turn: no usable abilities (hp<=60, index=%d, ready_dice=%d)" % [monster_index, available_dice.size()])
	return MonsterAiDecision.end_turn(&"no_priority_abilities")


func _can_use_ability(ability: AbilityDefinition, available_dice: Array[Dice], dice_value_penalty: int = 0) -> bool:
	if ability == null:
		return false
	return BattleAbilityRuntime.can_use_ability_with_dice(ability, available_dice, true, dice_value_penalty)


func _build_target_self(monster_index: int) -> Dictionary:
	var target_self := TARGET_SELF.duplicate()
	target_self["index"] = monster_index
	return target_self


func _find_ability_by_id(abilities: Array[AbilityDefinition], ability_id: String) -> AbilityDefinition:
	for ability in abilities:
		if ability == null:
			continue
		if ability.ability_id == ability_id:
			return ability
	return null


func _log_debug(message: String) -> void:
	print("[Debug][MonsterAI][GoblinShaman] %s" % message)
