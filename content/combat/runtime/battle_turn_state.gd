extends RefCounted
class_name BattleTurnState

var turn_owner_id := ""
var round_number := 1
var available_dice: Array[Dictionary] = []
var activated_ability_ids: PackedStringArray = PackedStringArray()
var can_end_turn := false
var end_reason := &""
var dice_pool: BattleDicePool


func refresh_available_dice() -> void:
	available_dice = dice_pool.get_available_dice() if dice_pool != null else []
