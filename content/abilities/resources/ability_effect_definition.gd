@tool
extends Resource
class_name AbilityEffectDefinition

# Generic effect payload used by ability resources.
# Runtime systems can interpret these values to execute damage,
# healing, status application, dice manipulation, summons, etc.

enum Timing {
	ON_USE,
	ON_HIT,
	ON_MISS,
	ON_TURN_START,
	ON_TURN_END,
	PASSIVE,
	CUSTOM,
}

@export var effect_id := ""
@export var effect_type := &"damage"
@export var timing: Timing = Timing.ON_USE
@export var magnitude := 0
@export var scale_with_power := 0.0
@export var repeat_count := 1
@export var chance := 1.0
@export var status_id := ""
@export var dice_query_tags: PackedStringArray = PackedStringArray()
@export var parameters: Dictionary = {}


func is_valid_definition() -> bool:
	return not effect_id.is_empty() and effect_type != &""


func uses_status() -> bool:
	return not status_id.is_empty()


func duplicates_dice_selection() -> bool:
	return parameters.get("duplicate_selected_die", false)
