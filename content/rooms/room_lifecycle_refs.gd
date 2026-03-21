@tool
extends Resource
class_name RoomLifecycleRefs

@export var prepare_ref: StringName
@export var enter_ref: StringName
@export var activate_ref: StringName
@export var complete_ref: StringName
@export var leave_ref: StringName
@export var fail_ref: StringName


func get_all_refs() -> PackedStringArray:
	var refs := PackedStringArray()
	for ref_value in [prepare_ref, enter_ref, activate_ref, complete_ref, leave_ref, fail_ref]:
		if not String(ref_value).is_empty():
			refs.append(String(ref_value))
	return refs


func has_any_ref() -> bool:
	return get_all_refs().size() > 0
