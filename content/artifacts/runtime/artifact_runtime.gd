extends RefCounted
class_name ArtifactRuntime

const StatusRuntime = preload("res://content/statuses/runtime/status_runtime.gd")
const EVENT_BATTLE_START := &"on_battle_start"
const EVENT_TURN_END := &"on_turn_end"


static func trigger_event(event_name: StringName, battle_room, owner_descriptor: Dictionary, artifacts: Array[ArtifactDefinition]) -> void:
	if battle_room == null or event_name == &"":
		return
	var trigger_entries: Array[Dictionary] = []
	for artifact in artifacts:
		if artifact == null:
			continue
		for trigger in artifact.triggers:
			if trigger == null or trigger.event_name != event_name:
				continue
			trigger_entries.append({
				"artifact_id": StringName(artifact.artifact_id),
				"trigger": trigger,
				"priority": trigger.priority,
				"phase_order": trigger.phase_order,
				"trigger_id": StringName(trigger.trigger_id),
			})
	if trigger_entries.is_empty():
		return
	trigger_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority := int(left.get("priority", 0))
		var right_priority := int(right.get("priority", 0))
		if left_priority != right_priority:
			return left_priority > right_priority
		var left_phase_order := int(left.get("phase_order", 0))
		var right_phase_order := int(right.get("phase_order", 0))
		if left_phase_order != right_phase_order:
			return left_phase_order < right_phase_order
		return String(left.get("trigger_id", &"")) < String(right.get("trigger_id", &""))
	)
	for entry in trigger_entries:
		_execute_trigger(battle_room, owner_descriptor, entry.get("trigger") as ArtifactTriggerDefinition)


static func _execute_trigger(battle_room, owner_descriptor: Dictionary, trigger: ArtifactTriggerDefinition) -> void:
	if trigger == null:
		return
	if trigger.effect_type == &"apply_status":
		var status_definition := trigger.parameters.get("status_definition") as StatusDefinition
		if status_definition == null:
			return
		var stacks := maxi(int(trigger.parameters.get("stacks", 1)), 1)
		var target_descriptor := _resolve_target_descriptor(owner_descriptor, trigger.target_scope)
		if target_descriptor.is_empty():
			return
		StatusRuntime.apply_status(battle_room, target_descriptor, status_definition, stacks, owner_descriptor)
		return

	if trigger.effect_type == &"convert_status_on_remove":
		_execute_convert_status_on_remove_trigger(battle_room, owner_descriptor, trigger)


static func _resolve_target_descriptor(owner_descriptor: Dictionary, target_scope: StringName) -> Dictionary:
	if target_scope == &"player":
		return {"side": &"player"}
	if target_scope == &"self":
		return owner_descriptor.duplicate(true)
	return owner_descriptor.duplicate(true)


static func _execute_convert_status_on_remove_trigger(battle_room, owner_descriptor: Dictionary, trigger: ArtifactTriggerDefinition) -> void:
	var source_status_definition := trigger.parameters.get("source_status_definition") as StatusDefinition
	var target_status_definition := trigger.parameters.get("target_status_definition") as StatusDefinition
	if source_status_definition == null or target_status_definition == null:
		_log_debug("convert_status_on_remove skipped: status definitions are not configured.")
		return

	var target_descriptor := _resolve_target_descriptor(owner_descriptor, trigger.target_scope)
	if target_descriptor.is_empty():
		return

	var remove_stacks := maxi(int(trigger.parameters.get("remove_stacks", 1)), 1)
	var per_removed_stack := maxi(int(trigger.parameters.get("target_stacks_per_removed_stack", 1)), 1)
	var previous_stacks := _get_status_stacks(battle_room, target_descriptor, StringName(source_status_definition.status_id))
	if previous_stacks <= 0:
		_log_debug("convert_status_on_remove skipped: source status is absent.")
		return

	StatusRuntime.remove_status(battle_room, target_descriptor, StringName(source_status_definition.status_id), remove_stacks)
	var current_stacks := _get_status_stacks(battle_room, target_descriptor, StringName(source_status_definition.status_id))
	var removed_stacks := maxi(previous_stacks - current_stacks, 0)
	if removed_stacks <= 0:
		return

	var apply_stacks := removed_stacks * per_removed_stack
	StatusRuntime.apply_status(battle_room, target_descriptor, target_status_definition, apply_stacks, owner_descriptor)
	_log_debug("convert_status_on_remove: removed=%d applied=%d source=%s target=%s" % [
		removed_stacks,
		apply_stacks,
		String(source_status_definition.status_id),
		String(target_status_definition.status_id),
	])


static func _get_status_stacks(battle_room, target_descriptor: Dictionary, status_id: StringName) -> int:
	if battle_room == null or status_id == &"":
		return 0
	var container := battle_room.get_status_container_for_descriptor(target_descriptor)
	if container == null:
		return 0
	var instance := container.get_status(status_id)
	if instance == null or not instance.is_effectively_active():
		return 0
	return instance.stacks


static func _log_debug(message: String) -> void:
	if not OS.is_debug_build():
		return
	print("[ArtifactRuntime] %s" % message)
