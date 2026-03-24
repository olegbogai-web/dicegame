@tool
extends Resource
class_name EventDefinition

const EventChoiceDefinition = preload("res://content/events/resources/event_choice_definition.gd")

@export var event_id: StringName
@export var background_texture: Texture2D
@export_multiline var event_text := ""
@export var choices: Array[EventChoiceDefinition] = []


func is_valid_event() -> bool:
	if event_id.is_empty() or background_texture == null or event_text.is_empty() or choices.is_empty():
		return false
	for choice in choices:
		if choice == null or not choice.is_valid_choice():
			return false
	return true
