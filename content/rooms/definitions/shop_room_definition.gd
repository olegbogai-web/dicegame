@tool
extends RoomDefinition
class_name ShopRoomDefinition


func _init() -> void:
	super()
	room_type = RoomEnums.RoomType.SHOP


@export_category("Shop")
@export var shop_pool_ref: StringName
@export var inventory_generation_ref: StringName
@export var pricing_policy_ref: StringName
@export var shop_rule_refs: PackedStringArray = PackedStringArray()
@export var shop_slot_layout_ref: StringName
@export var currency_rule_ref: StringName
@export var shop_visual_ref: StringName
@export var refresh_policy_ref: StringName


func get_expected_room_type() -> RoomEnums.RoomType:
	return RoomEnums.RoomType.SHOP


func is_valid_definition() -> bool:
	return super.is_valid_definition() and room_type == get_expected_room_type()
