@tool
extends Resource
class_name EventOutcomeDefinition

enum OutcomeKind {
	POSITIVE,
	NEUTRAL,
	NEGATIVE,
}

@export_category("Identity")
@export var outcome_id := ""
@export var display_name := "New Outcome"
@export_multiline var result_text := ""
@export var kind: OutcomeKind = OutcomeKind.NEUTRAL
@export var weight := 1
@export var consequence_refs: PackedStringArray = PackedStringArray()


func is_valid_definition() -> bool:
	return not outcome_id.is_empty() and not result_text.is_empty() and weight >= 0
