extends RefCounted
class_name TurnState

const CombatEnums = preload("res://content/combat/resources/combat_enums.gd")
const TurnDicePool = preload("res://content/combat/runtime/turn_dice_pool.gd")
const TurnDie = preload("res://content/combat/runtime/turn_die.gd")

var turn_owner_id := ""
var round_index := 1
var turn_index := 1
var dice_pool: TurnDicePool = TurnDicePool.new()
var activated_ability_ids: PackedStringArray = PackedStringArray()
var can_end_turn := true
var end_reason: CombatEnums.TurnEndReason = CombatEnums.TurnEndReason.MANUAL


func _init(next_owner_id: String = "", next_round_index: int = 1, next_turn_index: int = 1) -> void:
	turn_owner_id = next_owner_id
	round_index = maxi(next_round_index, 1)
	turn_index = maxi(next_turn_index, 1)


func set_rolled_dice(dice: Array[TurnDie]) -> void:
	dice_pool.set_rolled_dice(dice)


func get_available_dice() -> Array[TurnDie]:
	return dice_pool.get_available_dice()


func mark_ability_used(ability_id: String) -> void:
	if not ability_id.is_empty():
		activated_ability_ids.append(ability_id)
