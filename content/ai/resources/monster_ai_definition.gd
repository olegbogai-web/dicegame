@tool
extends Resource
class_name MonsterAIDefinition

@export var ai_id := ""
@export var display_name := "New Monster AI"
@export_multiline var description := ""
@export var tags: PackedStringArray = PackedStringArray()
@export var planner_id := ""
@export var behavior_tags: PackedStringArray = PackedStringArray()
@export var parameters: Dictionary = {}


func is_valid_definition() -> bool:
	return not ai_id.is_empty() and not display_name.is_empty()
