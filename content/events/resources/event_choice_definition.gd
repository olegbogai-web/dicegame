@tool
extends Resource
class_name EventChoiceDefinition

const EventOutcomeDefinition = preload("res://content/events/resources/event_outcome_definition.gd")

@export var choice_id: StringName
@export_multiline var choice_text := ""
@export_range(0, 6, 1) var green_faces := 0
@export_range(0, 6, 1) var yellow_faces := 0
@export_range(0, 6, 1) var red_faces := 0

@export var green_outcome: EventOutcomeDefinition
@export var yellow_outcome: EventOutcomeDefinition
@export var red_outcome: EventOutcomeDefinition


func get_total_faces() -> int:
	return green_faces + yellow_faces + red_faces


func is_valid_choice() -> bool:
	return not choice_id.is_empty() \
		and not choice_text.is_empty() \
		and get_total_faces() > 0 \
		and green_outcome != null \
		and yellow_outcome != null \
		and red_outcome != null
