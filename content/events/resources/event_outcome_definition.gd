@tool
extends Resource
class_name EventOutcomeDefinition


enum OutcomeColor {
	GREEN,
	YELLOW,
	RED,
}


@export var color: OutcomeColor = OutcomeColor.YELLOW
@export_multiline var text := ""
