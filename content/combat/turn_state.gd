extends RefCounted
class_name TurnState

const TurnDicePoolScript = preload("res://content/combat/turn_dice_pool.gd")

var turn_owner_id: StringName = &""
var round_index := 0
var activated_ability_ids: PackedStringArray = PackedStringArray()
var end_reason: StringName = &""
var dice_pool: TurnDicePool = TurnDicePoolScript.new()


func configure(next_turn_owner_id: StringName, next_round_index: int, rolled_dice: Array[Dictionary]) -> void:
	turn_owner_id = next_turn_owner_id
	round_index = next_round_index
	activated_ability_ids = PackedStringArray()
	end_reason = &""
	dice_pool.configure(turn_owner_id, rolled_dice)


func mark_ability_used(ability_id: StringName) -> void:
	if ability_id == &"":
		return
	activated_ability_ids.append(ability_id)


func finish(reason: StringName) -> void:
	end_reason = reason
