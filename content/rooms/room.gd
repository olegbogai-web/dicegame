extends RefCounted
class_name Room

var room_id := ""
var room_type: RoomEnums.RoomType = RoomEnums.RoomType.UNKNOWN
var run_node_id := ""
var room_definition: RoomDefinition
var object_set: RoomObjectSet
var rule_set: RoomRuleSet
var state: RoomState
var lifecycle_refs: RoomLifecycleRefs
var visual_config: RoomVisualConfig
var room_rule_resolver_ref: StringName
var room_visual_binder_ref: StringName
var room_completion_handler_ref: StringName
var event_hook_refs: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


func _init() -> void:
	room_definition = RoomDefinition.new()
	object_set = RoomObjectSet.new()
	rule_set = RoomRuleSet.new()
	state = RoomState.new()
	lifecycle_refs = RoomLifecycleRefs.new()
	visual_config = RoomVisualConfig.new()


func apply_definition(definition: RoomDefinition) -> void:
	if definition == null:
		return
	room_definition = definition
	room_type = definition.room_type
	if definition.lifecycle_refs != null:
		lifecycle_refs = definition.lifecycle_refs
	if definition.visual_config != null:
		visual_config = definition.visual_config
	rule_set.rule_refs = definition.allowed_rule_refs.duplicate()
	metadata = definition.metadata.duplicate(true)


func has_rule(rule_ref: StringName) -> bool:
	return rule_set != null and rule_set.has_rule(rule_ref)


func has_visual_scene() -> bool:
	return visual_config != null and visual_config.has_scene()


func get_room_type_tag() -> String:
	return RoomEnums.get_room_type_tag(room_type)


func is_valid_room() -> bool:
	return not room_id.is_empty() and room_type != RoomEnums.RoomType.UNKNOWN and state != null
