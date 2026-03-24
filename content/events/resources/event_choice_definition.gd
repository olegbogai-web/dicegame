@tool
extends Resource
class_name EventChoiceDefinition

@export var choice_id: StringName
@export_multiline var choice_text := ""
@export_range(0, 6, 1) var green_faces := 0
@export_range(0, 6, 1) var yellow_faces := 0
@export_range(0, 6, 1) var red_faces := 0
@export_multiline var positive_text := ""
@export_multiline var neutral_text := ""
@export_multiline var negative_text := ""


func get_total_faces() -> int:
	return green_faces + yellow_faces + red_faces


func is_valid_choice() -> bool:
	return not String(choice_id).is_empty() and not choice_text.is_empty() and get_total_faces() > 0
