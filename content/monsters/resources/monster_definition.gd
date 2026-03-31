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
@export var combat_dice_loadout: Array[DiceDefinition] = []
@export var ai_profile: MonsterAiProfile
@export var abilities: Array[AbilityDefinition] = []


func is_valid_definition() -> bool:
	if monster_id.is_empty() or display_name.is_empty():
		return false
	if max_health <= 0 or dice_count < 0 or ai_profile == null:
		return false
	for dice_definition in combat_dice_loadout:
		if dice_definition == null:
			return false
		if dice_definition.scope != DiceDefinition.Scope.COMBAT:
			return false
	for ability in abilities:
		if ability == null or not ability.is_valid_definition():
			return false
	return true


func get_resolved_combat_dice_loadout() -> Array[DiceDefinition]:
	var resolved: Array[DiceDefinition] = []
	for dice_definition in combat_dice_loadout:
		if dice_definition == null:
			continue
		if dice_definition.scope != DiceDefinition.Scope.COMBAT:
			continue
		resolved.append(dice_definition)
	return resolved


func get_resolved_dice_count() -> int:
	var resolved_loadout := get_resolved_combat_dice_loadout()
	if not resolved_loadout.is_empty():
		return resolved_loadout.size()
	return maxi(dice_count, 0)
