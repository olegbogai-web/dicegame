@tool
extends Resource
class_name StatusDefinition

@export var status_id := ""
@export var display_name := "New Status"
@export_multiline var description := ""
@export var tags: PackedStringArray = PackedStringArray()
@export_range(1, 999, 1) var max_stacks := 1
@export_range(-1, 999, 1) var base_duration := -1
@export var is_positive := false
@export var is_hidden := false
@export var runtime_metadata: Dictionary = {}


func is_valid_definition() -> bool:
	return not status_id.is_empty() and not display_name.is_empty() and max_stacks > 0
