@tool
extends RoomDefinition
class_name EventRoomDefinition


func _init() -> void:
	super()
	room_type = RoomEnums.RoomType.EVENT


@export_category("Event")
@export var event_scenario_ref: StringName
@export var event_text_ref: StringName
@export var choice_set_ref: StringName
@export var choice_condition_refs: PackedStringArray = PackedStringArray()
@export var choice_resolution_ref: StringName
@export var event_rule_refs: PackedStringArray = PackedStringArray()
@export var event_visual_ref: StringName


func get_expected_room_type() -> RoomEnums.RoomType:
	return RoomEnums.RoomType.EVENT


func is_valid_definition() -> bool:
	return super.is_valid_definition() and room_type == get_expected_room_type()
