@tool
extends Resource
class_name StatusEffectDefinition

# Generic status effect payload.
# Runtime interprets fields by effect_type / trigger to keep content data-driven.

@export var effect_id := ""
@export var effect_type: StringName = &"modifier"
@export var trigger: StringName = &"passive"
@export var priority := 0
@export var phase_order := 0
@export var stat_key: StringName = &""
@export var operation: StringName = &"add"
@export var value := 0.0
@export var target_scope: StringName = &"self"
@export var status_id := ""
@export var parameters: Dictionary = {}


func is_valid_definition() -> bool:
	return not effect_id.is_empty() and effect_type != &"" and trigger != &""
