@tool
extends Resource
class_name AbilityDiceCondition

# Describes what kind of dice can pay or empower an ability.
# It is intentionally generic so the same model can work for player,
# monster and future map-dice abilities.

enum Scope {
	COMBAT,
	MAP,
	ANY,
}

@export var scope: Scope = Scope.COMBAT
@export_range(0, 99, 1) var min_value := 0
@export_range(0, 99, 1) var max_value := 99
@export_range(1, 20, 1) var required_count := 1
@export_range(0, 20, 1) var min_selected_count := 0
@export_range(0, 20, 1) var max_selected_count := 0
@export_range(0, 200, 1) var min_total_value := 0
@export_range(0, 200, 1) var max_total_value := 0
@export_range(0, 20, 1) var slot_count_hint := 0
@export var requires_exact_count := false
@export var requires_same_value := false
@export var requires_unique_values := false
@export var required_tags: PackedStringArray = PackedStringArray()
@export var forbidden_tags: PackedStringArray = PackedStringArray()
@export var accepted_face_ids: PackedStringArray = PackedStringArray()
@export var consume_on_use := true
@export var grant_value_as_power := true
@export var consume_order := PackedStringArray()


func matches_value(value: int) -> bool:
	return value >= min_value and value <= max_value


func has_tag_filters() -> bool:
	return required_tags.size() > 0 or forbidden_tags.size() > 0


func requires_face_filter() -> bool:
	return accepted_face_ids.size() > 0


func get_min_selected_count() -> int:
	return maxi(min_selected_count, required_count)


func get_max_selected_count() -> int:
	var min_count := get_min_selected_count()
	var resolved_max := max_selected_count if max_selected_count > 0 else min_count
	if requires_exact_count:
		return min_count
	return maxi(resolved_max, min_count)


func get_slot_count() -> int:
	var max_count := get_max_selected_count()
	return slot_count_hint if slot_count_hint > 0 else max_count


func matches_total_value(total_value: int) -> bool:
	if min_total_value > 0 and total_value < min_total_value:
		return false
	if max_total_value > 0 and total_value > max_total_value:
		return false
	return true
