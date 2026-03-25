@tool
extends Resource
class_name EventChoiceDefinition

const EventOutcomeDefinitionScript = preload("res://content/events/resources/event_outcome_definition.gd")

@export var choice_id: StringName
@export_multiline var choice_text := ""
@export var event_dice_definition: DiceDefinition
@export var outcomes: Array[EventOutcomeDefinition] = []


func get_outcomes_for_color(color_tag: StringName) -> Array[EventOutcomeDefinition]:
	var result: Array[EventOutcomeDefinition] = []
	for outcome in outcomes:
		if outcome == null:
			continue
		if outcome.get_outcome_color_tag() == color_tag:
			result.append(outcome)
	return result
