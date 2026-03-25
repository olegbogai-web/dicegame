@tool
extends Resource
class_name EventOutcomeDefinition

@export_enum("green", "yellow", "red") var outcome_color := "yellow"
@export_multiline var outcome_text := ""
