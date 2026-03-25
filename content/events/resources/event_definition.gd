@tool
extends Resource
class_name EventDefinition

@export var event_id: StringName
@export var background_texture: Texture2D
@export_multiline var event_text := ""
@export var choices: Array[EventChoiceDefinition] = []
