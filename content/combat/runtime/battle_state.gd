extends RefCounted
class_name BattleState

const BattleEnums = preload("res://content/combat/resources/battle_enums.gd")

var battle_id := ""
var phase: BattleEnums.Phase = BattleEnums.Phase.SETUP
var round_number := 1
var combatants: Array[BattleCombatant] = []
var active_turn: BattleTurnState
var active_combatant_id := ""
var turn_order: PackedStringArray = PackedStringArray()
var battle_log: PackedStringArray = PackedStringArray()
var is_finished := false
var result: BattleResult = BattleResult.new()


func get_player() -> BattleCombatant:
	for combatant in combatants:
		if combatant.side == BattleEnums.Side.PLAYER:
			return combatant
	return null


func get_enemies(include_dead: bool = false) -> Array[BattleCombatant]:
	var enemies: Array[BattleCombatant] = []
	for combatant in combatants:
		if combatant.side != BattleEnums.Side.ENEMY:
			continue
		if include_dead or combatant.is_alive():
			enemies.append(combatant)
	return enemies


func get_combatant(combatant_id: String) -> BattleCombatant:
	for combatant in combatants:
		if combatant.combatant_id == combatant_id:
			return combatant
	return null


func append_log(entry: String) -> void:
	if entry.is_empty():
		return
	battle_log.append(entry)
	if battle_log.size() > 30:
		battle_log.remove_at(0)
