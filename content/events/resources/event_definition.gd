@tool
extends Resource
class_name EventDefinition

@export var event_id := ""
@export var display_name := ""
@export var background_texture: Texture2D
@export_multiline var event_text := ""
@export var choices: Array[EventChoiceDefinition] = []
@export var metadata: Dictionary = {}
