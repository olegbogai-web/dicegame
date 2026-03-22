@tool
extends Resource
class_name MonsterDefinition

@export_category("Identity")
@export var monster_id := ""
@export var display_name := "New Monster"
@export_multiline var description := ""
@export var sprite: Texture2D
@export var tags: PackedStringArray = PackedStringArray()

@export_category("Combat")
@export_range(1, 999, 1) var max_health := 1
@export_range(0, 99, 1) var dice_count := 0
@export var abilities: Array[AbilityDefinition] = []


func is_valid_definition() -> bool:
	if monster_id.is_empty() or display_name.is_empty():
		return false
	if max_health <= 0 or dice_count < 0:
		return false
	for ability in abilities:
		if ability == null or not ability.is_valid_definition():
			return false
	return true
