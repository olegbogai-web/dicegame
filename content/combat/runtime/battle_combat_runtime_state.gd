extends RefCounted
class_name BattleCombatRuntimeState

const CombatantRuntimeState = preload("res://content/combat/runtime/combatant_runtime_state.gd")

var player_state: CombatantRuntimeState
var monster_states: Array[CombatantRuntimeState] = []
var status_event_log: Array[Dictionary] = []
var _turn_start_dice_penalty_by_owner: Dictionary = {}


func set_player_state(combatant_id: StringName, side: StringName = &"player") -> void:
	player_state = CombatantRuntimeState.new(combatant_id, side)


func set_monster_states(combatant_descriptors: Array[Dictionary]) -> void:
	monster_states.clear()
	for descriptor in combatant_descriptors:
		var combatant_id := StringName(descriptor.get("combatant_id", &""))
		var side := StringName(descriptor.get("side", &"enemy"))
		monster_states.append(CombatantRuntimeState.new(combatant_id, side))


func get_status_container_for_descriptor(descriptor: Dictionary):
	var combatant_state := _get_combatant_state_for_descriptor(descriptor)
	if combatant_state == null or not combatant_state.is_alive:
		return null
	return combatant_state.statuses


func _get_combatant_state_for_descriptor(descriptor: Dictionary) -> CombatantRuntimeState:
	var side := StringName(descriptor.get("side", &""))
	if side == &"player":
		return player_state
	if side == &"enemy":
		var monster_index := int(descriptor.get("index", -1))
		if monster_index < 0 or monster_index >= monster_states.size():
			return null
		var monster_state := monster_states[monster_index]
		if monster_state == null:
			return null
		return monster_state
	return null


func get_status_container_for_turn_owner(turn_owner: StringName, monster_turn_index: int):
	var descriptor := {"side": turn_owner}
	if turn_owner == &"monster":
		descriptor["side"] = &"enemy"
		descriptor["index"] = monster_turn_index
	return get_status_container_for_descriptor(descriptor)


func clear_all_statuses() -> void:
	if player_state != null and player_state.statuses != null:
		player_state.statuses.clear()
	for monster_state in monster_states:
		if monster_state != null and monster_state.statuses != null:
			monster_state.statuses.clear()
	_turn_start_dice_penalty_by_owner.clear()
	clear_status_event_log()


func mark_combatant_dead(descriptor: Dictionary) -> void:
	var combatant_state := _get_combatant_state_for_descriptor(descriptor)
	if combatant_state == null:
		return
	combatant_state.is_alive = false
	if combatant_state.statuses != null:
		combatant_state.statuses.clear()
	_turn_start_dice_penalty_by_owner.erase(_build_owner_key(descriptor))


func mark_combatant_alive(descriptor: Dictionary) -> void:
	var combatant_state := _get_combatant_state_for_descriptor(descriptor)
	if combatant_state == null:
		return
	combatant_state.is_alive = true


func publish_status_event(event_name: StringName, payload: Dictionary = {}) -> void:
	status_event_log.append({
		"event_name": event_name,
		"payload": payload,
	})


func get_status_event_log() -> Array[Dictionary]:
	return status_event_log.duplicate(true)


func clear_status_event_log() -> void:
	status_event_log.clear()


func add_turn_start_dice_penalty(descriptor: Dictionary, penalty: int) -> int:
	var resolved_penalty := maxi(penalty, 0)
	if resolved_penalty <= 0:
		return 0
	var owner_key := _build_owner_key(descriptor)
	if owner_key == &"":
		return 0
	var current_penalty := int(_turn_start_dice_penalty_by_owner.get(owner_key, 0))
	var next_penalty := current_penalty + resolved_penalty
	_turn_start_dice_penalty_by_owner[owner_key] = next_penalty
	return next_penalty


func consume_turn_start_dice_penalty(descriptor: Dictionary) -> int:
	var owner_key := _build_owner_key(descriptor)
	if owner_key == &"":
		return 0
	var penalty := maxi(int(_turn_start_dice_penalty_by_owner.get(owner_key, 0)), 0)
	_turn_start_dice_penalty_by_owner.erase(owner_key)
	return penalty


func _build_owner_key(descriptor: Dictionary) -> StringName:
	var side := StringName(descriptor.get("side", &""))
	if side == &"player":
		return &"player"
	if side == &"enemy":
		return StringName("enemy_%d" % int(descriptor.get("index", -1)))
	return &""
