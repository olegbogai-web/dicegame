@tool
extends Resource
class_name ArtifactDefinition

@export var artifact_id := ""
@export var display_name := "New Artifact"
@export_multiline var description := ""
@export var rarity: StringName = &"common"
@export var sprite: Texture2D
@export var tags: PackedStringArray = PackedStringArray()
@export var modifiers: Array[StatusEffectDefinition] = []
@export var triggers: Array[ArtifactTriggerDefinition] = []
@export var metadata: Dictionary = {}


func is_valid_definition() -> bool:
	if artifact_id.is_empty() or display_name.is_empty() or rarity == &"":
		return false
	for modifier in modifiers:
		if modifier == null or not modifier.is_valid_definition():
			return false
	for trigger in triggers:
		if trigger == null or not trigger.is_valid_definition():
			return false
	return true
