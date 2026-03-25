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
