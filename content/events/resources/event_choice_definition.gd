@tool
extends Resource
class_name EventChoiceDefinition

const MIN_FACE_COUNT := 0

@export var choice_id: StringName
@export_multiline var choice_text := ""
@export_range(0, 6, 1) var green_faces := 0
@export_range(0, 6, 1) var yellow_faces := 0
@export_range(0, 6, 1) var red_faces := 0
@export var positive_outcome: EventOutcomeDefinition
@export var neutral_outcome: EventOutcomeDefinition
@export var negative_outcome: EventOutcomeDefinition


func get_total_faces() -> int:
	return maxi(green_faces, MIN_FACE_COUNT) + maxi(yellow_faces, MIN_FACE_COUNT) + maxi(red_faces, MIN_FACE_COUNT)


func is_valid_choice() -> bool:
	return not choice_id.is_empty() and not choice_text.is_empty() and get_total_faces() > 0
