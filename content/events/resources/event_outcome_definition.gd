@tool
extends Resource
class_name EventOutcomeDefinition

enum OutcomeColor {
	GREEN,
	YELLOW,
	RED,
}

@export var outcome_id: StringName
@export var outcome_color: OutcomeColor = OutcomeColor.YELLOW
@export_multiline var outcome_text := ""


func get_outcome_color_tag() -> StringName:
	match outcome_color:
		OutcomeColor.GREEN:
			return &"green"
		OutcomeColor.YELLOW:
			return &"yellow"
		OutcomeColor.RED:
			return &"red"
		_:
			return &"yellow"
