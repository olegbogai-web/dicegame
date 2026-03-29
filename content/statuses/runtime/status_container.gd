extends RefCounted
class_name StatusContainer

const StatusInstance = preload("res://content/statuses/runtime/status_instance.gd")

var owner_id: StringName = &""
var _status_by_id: Dictionary = {}


func _init(next_owner_id: StringName = &"") -> void:
	owner_id = next_owner_id


func add_status(definition: StatusDefinition, stacks: int = 1) -> StatusInstance:
	if definition == null or definition.status_id.is_empty():
		return null
	var status_id := StringName(definition.status_id)
	var resolved_stacks := maxi(stacks, 1)
	var existing := get_status(status_id)
	if existing != null:
		existing.add_stacks(_resolve_reapply_stacks(existing, resolved_stacks))
		return existing
	var instance := StatusInstance.new(definition, owner_id, mini(resolved_stacks, definition.max_stacks))
	_status_by_id[status_id] = instance
	return instance


func remove_status(status_id: StringName, stacks: int = -1) -> bool:
	var instance := get_status(status_id)
	if instance == null:
		return false
	if stacks < 0:
		_status_by_id.erase(status_id)
		return true
	instance.remove_stacks(stacks)
	if instance.stacks <= 0:
		_status_by_id.erase(status_id)
	return true


func clear() -> void:
	_status_by_id.clear()


func get_status(status_id: StringName) -> StatusInstance:
	if not _status_by_id.has(status_id):
		return null
	var value = _status_by_id[status_id]
	return value as StatusInstance


func get_active_statuses() -> Array[StatusInstance]:
	var statuses: Array[StatusInstance] = []
	for value in _status_by_id.values():
		if value is StatusInstance and value.is_active and value.stacks > 0:
			statuses.append(value as StatusInstance)
	return statuses


func has_status(status_id: StringName) -> bool:
	return get_status(status_id) != null


func _resolve_reapply_stacks(instance: StatusInstance, incoming_stacks: int) -> int:
	if instance == null or instance.definition == null:
		return incoming_stacks
	if instance.definition.stacking_policy == &"refresh_to_max":
		return maxi(instance.definition.max_stacks - instance.stacks, 0)
	return incoming_stacks
