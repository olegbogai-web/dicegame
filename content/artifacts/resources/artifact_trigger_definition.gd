@tool
extends Resource
class_name ArtifactTriggerDefinition

@export var trigger_id := ""
@export var event_name: StringName = &"on_battle_start"
@export var effect_type: StringName = &"apply_status"
@export var target_scope: StringName = &"player"
@export var priority := 0
@export var phase_order := 0
@export var parameters: Dictionary = {}


func is_valid_definition() -> bool:
	return not trigger_id.is_empty() and event_name != &"" and effect_type != &""
