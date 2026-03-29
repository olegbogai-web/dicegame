@tool
extends Resource
class_name StatusDefinition

const DEFAULT_MAX_STACKS := 99

@export var status_id := ""
@export var display_name := "New Status"
@export_multiline var description := ""
@export var asset: Texture2D
@export var stacking_policy: StringName = &"add"
@export_range(1, 999, 1) var max_stacks := DEFAULT_MAX_STACKS
@export var duration_model: StringName = &"battle"
@export var effects: Array[StatusEffectDefinition] = []
@export var metadata: Dictionary = {}


func is_valid_definition() -> bool:
	if status_id.is_empty() or display_name.is_empty() or max_stacks <= 0:
		return false
	for effect in effects:
		if effect == null or not effect.is_valid_definition():
			return false
	return true
