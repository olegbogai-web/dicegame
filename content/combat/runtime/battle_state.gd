extends RefCounted
class_name BattleState

const CombatEnums = preload("res://content/combat/resources/combat_enums.gd")
const BattleResult = preload("res://content/combat/runtime/battle_result.gd")
const CombatantRuntime = preload("res://content/combat/runtime/combatant_runtime.gd")
const TurnState = preload("res://content/combat/runtime/turn_state.gd")

var battle_id := ""
var source_room_id := ""
var phase: CombatEnums.BattlePhase = CombatEnums.BattlePhase.SETUP
var combatants: Array[CombatantRuntime] = []
var turn_state: TurnState
var active_combatant_id := ""
var current_round := 1
var total_turns_started := 0
var enemy_turn_order: Array[String] = []
var enemy_turn_cursor := 0
var event_log: Array[Dictionary] = []
var is_finished := false
var result: BattleResult = BattleResult.new()


func register_combatant(combatant: CombatantRuntime) -> void:
	if combatant != null:
		combatants.append(combatant)


func get_combatant(combatant_id: String) -> CombatantRuntime:
	for combatant in combatants:
		if combatant != null and combatant.combatant_id == combatant_id:
			return combatant
	return null


func get_player() -> CombatantRuntime:
	for combatant in combatants:
		if combatant != null and combatant.side == CombatEnums.Side.PLAYER:
			return combatant
	return null


func get_enemies(include_dead: bool = false) -> Array[CombatantRuntime]:
	var resolved: Array[CombatantRuntime] = []
	for combatant in combatants:
		if combatant == null or combatant.side != CombatEnums.Side.ENEMY:
			continue
		if include_dead or combatant.is_alive():
			resolved.append(combatant)
	return resolved


func get_opponents(of_combatant: CombatantRuntime, include_dead: bool = false) -> Array[CombatantRuntime]:
	var resolved: Array[CombatantRuntime] = []
	if of_combatant == null:
		return resolved
	for combatant in combatants:
		if combatant == null or combatant.side == of_combatant.side:
			continue
		if include_dead or combatant.is_alive():
			resolved.append(combatant)
	return resolved


func append_event(event_type: StringName, payload: Dictionary = {}) -> void:
	event_log.append({
		"event_type": event_type,
		"payload": payload.duplicate(true),
		"phase": phase,
		"active_combatant_id": active_combatant_id,
		"round": current_round,
	})
