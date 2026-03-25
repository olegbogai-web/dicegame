@tool
extends Resource
class_name EventDefinition

@export_category("Identity")
@export var event_id := ""
@export var display_name := "New Event"

@export_category("Presentation")
@export var background_texture: Texture2D
@export_multiline var event_text := ""

@export_category("Choices")
@export var choices: Array[EventChoiceDefinition] = []


func is_valid_definition() -> bool:
	if event_id.is_empty() or display_name.is_empty() or event_text.is_empty() or background_texture == null:
		return false
	if choices.is_empty():
		return false
	for choice in choices:
		if choice == null or not choice.is_valid_definition():
			return false
	return true
