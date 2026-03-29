extends RefCounted
class_name StatusInstance

var definition: StatusDefinition
var owner_id: StringName = &""
var stacks := 0
var runtime_counters: Dictionary = {}


func _init(next_definition: StatusDefinition = null, next_owner_id: StringName = &"", next_stacks: int = 1) -> void:
	definition = next_definition
	owner_id = next_owner_id
	if definition == null:
		stacks = 0
		return
	stacks = mini(maxi(next_stacks, 1), definition.max_stacks)


func get_status_id() -> StringName:
	if definition == null:
		return &""
	return StringName(definition.status_id)


func add_stacks(amount: int) -> int:
	if definition == null:
		return 0
	stacks = mini(stacks + maxi(amount, 0), definition.max_stacks)
	return stacks


func remove_stacks(amount: int) -> int:
	stacks = maxi(stacks - maxi(amount, 0), 0)
	return stacks


func has_stacks() -> bool:
	return stacks > 0


func is_effectively_active() -> bool:
	return definition != null and has_stacks()


func is_expired() -> bool:
	return not is_effectively_active()
