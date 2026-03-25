@tool
extends Resource
class_name EventOutcomeDefinition

@export_enum("green", "yellow", "red") var color_id := "yellow"
@export_multiline var result_text := ""
@export var metadata: Dictionary = {}
