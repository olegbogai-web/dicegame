extends RefCounted
class_name CombatantState

enum Side {
	PLAYER,
	ENEMY,
}

var combatant_id: StringName = &""
var display_name := ""
var side: Side = Side.ENEMY
var current_hp := 0
var max_hp := 0
var dice_count := 0
var abilities: Array[AbilityDefinition] = []
var sprite: Texture2D
var spawn_index := 0
var metadata: Dictionary = {}


func is_alive() -> bool:
	return current_hp > 0


func is_player() -> bool:
	return side == Side.PLAYER


func take_damage(amount: int) -> int:
	var resolved_amount := maxi(amount, 0)
	var previous_hp := current_hp
	current_hp = maxi(current_hp - resolved_amount, 0)
	return previous_hp - current_hp


func heal(amount: int) -> int:
	var resolved_amount := maxi(amount, 0)
	var previous_hp := current_hp
	current_hp = mini(current_hp + resolved_amount, max_hp)
	return current_hp - previous_hp
