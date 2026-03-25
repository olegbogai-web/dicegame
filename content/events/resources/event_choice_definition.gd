@tool
extends Resource
class_name EventChoiceDefinition

@export var choice_id := ""
@export var choice_text := ""
@export var dice_definition: DiceDefinition
@export var positive_outcome: EventOutcomeDefinition
@export var neutral_outcome: EventOutcomeDefinition
@export var negative_outcome: EventOutcomeDefinition
@export var metadata: Dictionary = {}


func get_outcome_by_color(color_id: String) -> EventOutcomeDefinition:
	match color_id:
		"green":
			return positive_outcome
		"yellow":
			return neutral_outcome
		"red":
			return negative_outcome
		_:
			return null
