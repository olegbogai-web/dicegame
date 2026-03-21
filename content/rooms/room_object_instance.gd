extends RefCounted
class_name RoomObjectInstance

var object_id := ""
var object_definition_id := ""
var placement_ref: StringName
var availability_state: StringName = &"available"
var tags: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


static func create(
	new_object_id: String,
	definition_id: String = "",
	new_placement_ref: StringName = &"",
	extra_tags: PackedStringArray = PackedStringArray(),
	extra_metadata: Dictionary = {}
) -> RoomObjectInstance:
	var instance := RoomObjectInstance.new()
	instance.object_id = new_object_id
	instance.object_definition_id = definition_id
	instance.placement_ref = new_placement_ref
	instance.tags = PackedStringArray(extra_tags)
	instance.metadata = extra_metadata.duplicate(true)
	return instance


func is_available() -> bool:
	return availability_state == &"available"
