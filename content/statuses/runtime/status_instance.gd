extends RefCounted
class_name StatusInstance

var definition: StatusDefinition
var owner_id: StringName = &""
var stacks := 0
var is_active := true
var runtime_counters: Dictionary = {}


func _init(next_definition: StatusDefinition = null, next_owner_id: StringName = &"", next_stacks: int = 1) -> void:
	definition = next_definition
	owner_id = next_owner_id
	stacks = maxi(next_stacks, 1)
	is_active = definition != null


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
	is_active = stacks > 0
	return stacks
