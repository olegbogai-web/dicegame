extends RefCounted
class_name EntityStatusEntry

var definition: StatusDefinition
var stacks := 1
var remaining_duration := -1
var source_entity_id: StringName = StringName()
var metadata: Dictionary = {}


func configure(
	status_definition: StatusDefinition,
	status_stacks: int = 1,
	duration: int = -1,
	source_id: StringName = StringName(),
	extra_metadata: Dictionary = {}
) -> EntityStatusEntry:
	definition = status_definition
	stacks = max(status_stacks, 1)
	remaining_duration = duration
	source_entity_id = source_id
	metadata = extra_metadata.duplicate(true)
	return self


func get_status_id() -> StringName:
	if definition == null:
		return StringName()
	return StringName(definition.status_id)
