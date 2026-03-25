@tool
extends Resource
class_name EventChoiceDefinition

const EventOutcomeDefinitionScript = preload("res://content/events/resources/event_outcome_definition.gd")

@export var choice_id: StringName
@export var choice_text := ""
@export var event_dice_definition: DiceDefinition
@export var positive_outcome: EventOutcomeDefinition
@export var neutral_outcome: EventOutcomeDefinition
@export var negative_outcome: EventOutcomeDefinition


func get_outcome_for_color(color_key: String) -> EventOutcomeDefinition:
	match color_key:
		"green":
			return positive_outcome
		"yellow":
			return neutral_outcome
		"red":
			return negative_outcome
		_:
			return null


func is_valid_choice() -> bool:
	return (
		not choice_id.is_empty()
		and not choice_text.is_empty()
		and event_dice_definition != null
		and positive_outcome != null
		and neutral_outcome != null
		and negative_outcome != null
	)
