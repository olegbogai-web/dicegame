extends Resource
class_name EventChoiceDefinition

@export var choice_id: StringName
@export_multiline var choice_text := ""
@export var dice_definition: DiceDefinition
@export var positive_outcome: EventOutcomeDefinition
@export var neutral_outcome: EventOutcomeDefinition
@export var negative_outcome: EventOutcomeDefinition


func get_outcome_by_face(face_value: String) -> EventOutcomeDefinition:
	match face_value.to_lower():
		"green":
			return positive_outcome
		"yellow":
			return neutral_outcome
		"red":
			return negative_outcome
		_:
			return neutral_outcome
