@tool
extends RoomDefinition
class_name BattleRoomDefinition


func _init() -> void:
	super()
	room_type = RoomEnums.RoomType.BATTLE


@export_category("Battle")
@export var encounter_definition_ref: StringName
@export var monster_pool_ref: StringName
@export var encounter_generation_ref: StringName
@export var battle_rule_refs: PackedStringArray = PackedStringArray()
@export var battle_start_ref: StringName
@export var battle_completion_ref: StringName
@export var battle_visual_ref: StringName


func get_expected_room_type() -> RoomEnums.RoomType:
	return RoomEnums.RoomType.BATTLE


func is_valid_definition() -> bool:
	return super.is_valid_definition() and room_type == get_expected_room_type()
