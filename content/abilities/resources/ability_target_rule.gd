@tool
extends Resource
class_name AbilityTargetRule

# Shared target model for both heroes and monsters.
# Runtime targeting systems may extend this without touching ability assets.

enum Side {
	ALLY,
	ENEMY,
	ANY,
	SELF,
}

enum Selection {
	NONE,
	SINGLE,
	RANDOM,
	ALL,
	CONE,
	ROW,
	CUSTOM,
}

@export var side: Side = Side.ENEMY
@export var selection: Selection = Selection.SINGLE
@export_range(0, 32, 1) var min_targets := 1
@export_range(0, 32, 1) var max_targets := 1
@export var allow_self := false
@export var required_tags: PackedStringArray = PackedStringArray()
@export var forbidden_tags: PackedStringArray = PackedStringArray()
@export var can_target_dead := false
@export var range_limit := -1


func requires_target_selection() -> bool:
	return selection != Selection.NONE


func supports_multiple_targets() -> bool:
	return max_targets > 1 or selection == Selection.ALL
