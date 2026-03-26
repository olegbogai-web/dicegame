@tool
extends Resource
class_name PlayerBaseStat

const DEFAULT_MAX_HP := 30

@export_category("Identity")
@export var player_id := ""
@export var display_name := "New Player"
@export var tags: PackedStringArray = PackedStringArray()

@export_category("Base Stats")
@export_range(1, 999, 1) var max_hp := DEFAULT_MAX_HP
@export_range(0, 999, 1) var starting_hp := DEFAULT_MAX_HP
@export_range(0, 999, 1) var starting_armor := 0
@export var starting_dice: Array[DiceDefinition] = []
@export var base_cube_global_map: Array[DiceDefinition] = []
@export var starting_abilities: Array[AbilityDefinition] = []
@export var metadata: Dictionary = {}


func get_resolved_starting_hp() -> int:
	return clampi(starting_hp, 0, max_hp)


func is_valid_definition() -> bool:
	if player_id.is_empty() or display_name.is_empty() or max_hp <= 0:
		return false
	for dice_definition in starting_dice:
		if dice_definition == null:
			return false
	for global_map_dice_definition in base_cube_global_map:
		if global_map_dice_definition == null:
			return false
	for ability_definition in starting_abilities:
		if ability_definition == null or not ability_definition.supports_owner(true):
			return false
	return true
