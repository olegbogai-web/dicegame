extends RefCounted
class_name BattleState

const CombatantStateScript = preload("res://content/combat/combatant_state.gd")
const TurnStateScript = preload("res://content/combat/turn_state.gd")

var battle_id: StringName = &""
var combatants: Array[CombatantState] = []
var active_combatant_id: StringName = &""
var active_turn: TurnState = TurnStateScript.new()
var round_index := 1
var battle_phase: StringName = &"setup"
var is_finished := false
var result_code: StringName = &""
var result_reason: StringName = &""


func get_combatant(combatant_id: StringName) -> CombatantState:
	for combatant in combatants:
		if combatant.combatant_id == combatant_id:
			return combatant
	return null


func get_player() -> CombatantState:
	for combatant in combatants:
		if combatant.side == CombatantStateScript.Side.PLAYER:
			return combatant
	return null


func get_alive_enemies() -> Array[CombatantState]:
	var enemies: Array[CombatantState] = []
	for combatant in combatants:
		if combatant.side == CombatantStateScript.Side.ENEMY and combatant.is_alive():
			enemies.append(combatant)
	return enemies


func get_alive_allies(source: CombatantState) -> Array[CombatantState]:
	var allies: Array[CombatantState] = []
	if source == null:
		return allies
	for combatant in combatants:
		if combatant.side == source.side and combatant.is_alive():
			allies.append(combatant)
	return allies


func set_result(next_result_code: StringName, next_reason: StringName) -> void:
	is_finished = true
	result_code = next_result_code
	result_reason = next_reason
