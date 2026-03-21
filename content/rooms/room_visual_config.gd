@tool
extends Resource
class_name RoomVisualConfig

@export var visual_definition_id := ""
@export var scene: PackedScene
@export var layout_ref: StringName
@export var theme_ref: StringName
@export var ambient_audio_ref: StringName
@export var vfx_profile_ref: StringName
@export var metadata: Dictionary = {}


func has_scene() -> bool:
	return scene != null
