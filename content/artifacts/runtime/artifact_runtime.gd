extends RefCounted
class_name ArtifactRuntime

const StatusRuntime = preload("res://content/statuses/runtime/status_runtime.gd")
const EVENT_BATTLE_START := &"on_battle_start"


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


static func _resolve_target_descriptor(owner_descriptor: Dictionary, target_scope: StringName) -> Dictionary:
	if target_scope == &"player":
		return {"side": &"player"}
	if target_scope == &"self":
		return owner_descriptor.duplicate(true)
	return owner_descriptor.duplicate(true)
