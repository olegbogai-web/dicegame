extends RefCounted
class_name CombatantRuntime

const CombatEnums = preload("res://content/combat/resources/combat_enums.gd")
const DiceDefinition = preload("res://content/dice/resources/dice_definition.gd")

var combatant_id := ""
var display_name := ""
var side: CombatEnums.Side = CombatEnums.Side.ENEMY
var definition_ref: Resource
var current_hp := 0
var max_hp := 0
var armor := 0
var abilities: Array[AbilityDefinition] = []
var dice_loadout: Array[DiceDefinition] = []
var fallback_dice_count := 0
var spawn_index := 0
var tags: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


func is_alive() -> bool:
	return current_hp > 0


func get_dice_count() -> int:
	if not dice_loadout.is_empty():
		return dice_loadout.size()
	return maxi(fallback_dice_count, 0)


func take_damage(amount: int) -> int:
	var incoming := maxi(amount, 0)
	var blocked := mini(armor, incoming)
	armor -= blocked
	var hp_damage := incoming - blocked
	current_hp = maxi(current_hp - hp_damage, 0)
	return hp_damage


func heal(amount: int) -> int:
	var resolved := maxi(amount, 0)
	var previous := current_hp
	current_hp = mini(current_hp + resolved, max_hp)
	return current_hp - previous


func supports_ability(ability: AbilityDefinition) -> bool:
	return ability != null and ability.supports_owner(side == CombatEnums.Side.PLAYER)
