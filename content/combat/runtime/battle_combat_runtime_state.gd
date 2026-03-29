extends RefCounted
class_name BattleCombatRuntimeState

const CombatantRuntimeState = preload("res://content/combat/runtime/combatant_runtime_state.gd")

var player_state: CombatantRuntimeState
var monster_states: Array[CombatantRuntimeState] = []


func set_player_state(combatant_id: StringName, side: StringName = &"player") -> void:
	player_state = CombatantRuntimeState.new(combatant_id, side)


func set_monster_states(combatant_descriptors: Array[Dictionary]) -> void:
	monster_states.clear()
	for descriptor in combatant_descriptors:
		var combatant_id := StringName(descriptor.get("combatant_id", &""))
		var side := StringName(descriptor.get("side", &"enemy"))
		monster_states.append(CombatantRuntimeState.new(combatant_id, side))


func get_status_container_for_descriptor(descriptor: Dictionary):
	var side := StringName(descriptor.get("side", &""))
	if side == &"player":
		if player_state == null:
			return null
		return player_state.statuses
	if side == &"enemy":
		var monster_index := int(descriptor.get("index", -1))
		if monster_index < 0 or monster_index >= monster_states.size():
			return null
		var monster_state := monster_states[monster_index]
		if monster_state == null:
			return null
		return monster_state.statuses
	return null


func get_status_container_for_turn_owner(turn_owner: StringName, monster_turn_index: int):
	if turn_owner == &"player":
		if player_state == null:
			return null
		return player_state.statuses
	if turn_owner == &"monster":
		if monster_turn_index < 0 or monster_turn_index >= monster_states.size():
			return null
		var monster_state := monster_states[monster_turn_index]
		if monster_state == null:
			return null
		return monster_state.statuses
	return null


func clear_all_statuses() -> void:
	if player_state != null and player_state.statuses != null:
		player_state.statuses.clear()
	for monster_state in monster_states:
		if monster_state != null and monster_state.statuses != null:
			monster_state.statuses.clear()
