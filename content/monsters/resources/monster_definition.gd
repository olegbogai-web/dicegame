@tool
extends Resource
class_name MonsterDefinition

const DiceDefinition = preload("res://content/dice/resources/dice_definition.gd")

@export_category("Identity")
@export var monster_id := ""
@export var display_name := "New Monster"
@export_multiline var description := ""
@export var sprite: Texture2D
@export var tags: PackedStringArray = PackedStringArray()

@export_category("Combat")
@export_range(1, 999, 1) var max_health := 1
@export_range(0.2, 2.0, 0.01) var size_multiplier := 1.0
@export_range(0, 99, 1) var dice_count := 0
@export var dice_loadout: Array[DiceDefinition] = []
@export var ai_profile: MonsterAiProfile
@export var abilities: Array[AbilityDefinition] = []


func get_combat_dice_loadout() -> Array[DiceDefinition]:
	var resolved: Array[DiceDefinition] = []
	for dice_definition in dice_loadout:
		if dice_definition == null:
			continue
		if dice_definition.scope != DiceDefinition.Scope.COMBAT:
			continue
		resolved.append(dice_definition)
	return resolved


func get_combat_dice_count() -> int:
	var loadout := get_combat_dice_loadout()
	if not loadout.is_empty():
		return loadout.size()
	return maxi(dice_count, 0)


func is_valid_definition() -> bool:
	if monster_id.is_empty() or display_name.is_empty():
		return false
	if max_health <= 0 or dice_count < 0 or ai_profile == null:
		return false
	if size_multiplier < 0.2 or size_multiplier > 2.0:
		return false
	for dice_definition in dice_loadout:
		if dice_definition == null or dice_definition.scope != DiceDefinition.Scope.COMBAT:
			return false
	for ability in abilities:
		if ability == null or not ability.is_valid_definition():
			return false
	return true
