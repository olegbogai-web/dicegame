@tool
extends Resource
class_name RoomDefinition

@export_category("Identity")
@export var room_definition_id := ""
@export var display_name := "New Room"
@export_multiline var description := ""
@export var room_type: RoomEnums.RoomType = RoomEnums.RoomType.UNKNOWN
@export var tags: PackedStringArray = PackedStringArray()

@export_category("Composition")
@export var allowed_rule_refs: PackedStringArray = PackedStringArray()
@export var default_object_definition_ids: PackedStringArray = PackedStringArray()
@export var generation_table_refs: PackedStringArray = PackedStringArray()
@export var lifecycle_refs: RoomLifecycleRefs
@export var visual_config: RoomVisualConfig
@export var metadata: Dictionary = {}


func _init() -> void:
	if lifecycle_refs == null:
		lifecycle_refs = RoomLifecycleRefs.new()
	if visual_config == null:
		visual_config = RoomVisualConfig.new()


func is_valid_definition() -> bool:
	return not room_definition_id.is_empty() and room_type != RoomEnums.RoomType.UNKNOWN
