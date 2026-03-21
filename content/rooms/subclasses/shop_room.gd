extends Room
class_name ShopRoom


func _init() -> void:
	super()
	room_type = RoomEnums.RoomType.SHOP


var shop_definition: ShopRoomDefinition
var shop_pool_ref: StringName
var inventory_generation_ref: StringName
var pricing_policy_ref: StringName
var shop_rule_refs: PackedStringArray = PackedStringArray()
var shop_slot_layout_ref: StringName
var currency_rule_ref: StringName
var shop_visual_ref: StringName
var refresh_policy_ref: StringName
var generated_offers: Array[Dictionary] = []
var purchased_offer_ids: PackedStringArray = PackedStringArray()
var blocked_offer_ids: PackedStringArray = PackedStringArray()
var active_price_modifier_refs: PackedStringArray = PackedStringArray()


func apply_shop_definition(definition: ShopRoomDefinition) -> void:
	if definition == null:
		return
	shop_definition = definition
	apply_definition(definition)
	room_type = RoomEnums.RoomType.SHOP
	shop_pool_ref = definition.shop_pool_ref
	inventory_generation_ref = definition.inventory_generation_ref
	pricing_policy_ref = definition.pricing_policy_ref
	shop_rule_refs = definition.shop_rule_refs.duplicate()
	shop_slot_layout_ref = definition.shop_slot_layout_ref
	currency_rule_ref = definition.currency_rule_ref
	shop_visual_ref = definition.shop_visual_ref
	refresh_policy_ref = definition.refresh_policy_ref


func is_valid_room() -> bool:
	return super.is_valid_room() and room_type == RoomEnums.RoomType.SHOP
