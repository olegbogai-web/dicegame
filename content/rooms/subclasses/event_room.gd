extends Room
class_name EventRoom


func _init() -> void:
	super()
	room_type = RoomEnums.RoomType.EVENT


var event_definition: EventRoomDefinition
var event_scenario_ref: StringName
var event_text_ref: StringName
var choice_set_ref: StringName
var choice_condition_refs: PackedStringArray = PackedStringArray()
var choice_resolution_ref: StringName
var event_rule_refs: PackedStringArray = PackedStringArray()
var event_visual_ref: StringName
var revealed_choice_ids: PackedStringArray = PackedStringArray()
var locked_choice_ids: PackedStringArray = PackedStringArray()
var selected_choice_id: StringName
var is_resolution_applied := false
var consequence_refs: PackedStringArray = PackedStringArray()


func apply_event_definition(definition: EventRoomDefinition) -> void:
	if definition == null:
		return
	event_definition = definition
	apply_definition(definition)
	room_type = RoomEnums.RoomType.EVENT
	event_scenario_ref = definition.event_scenario_ref
	event_text_ref = definition.event_text_ref
	choice_set_ref = definition.choice_set_ref
	choice_condition_refs = definition.choice_condition_refs.duplicate()
	choice_resolution_ref = definition.choice_resolution_ref
	event_rule_refs = definition.event_rule_refs.duplicate()
	event_visual_ref = definition.event_visual_ref


func is_valid_room() -> bool:
	return super.is_valid_room() and room_type == RoomEnums.RoomType.EVENT
