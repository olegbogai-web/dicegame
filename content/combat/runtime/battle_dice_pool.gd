extends RefCounted
class_name BattleDicePool

var rolled_dice: Array[Dictionary] = []
var consumed_until_next_turn: Array[Dictionary] = []
var _next_dice_id := 1


func roll_for_combatant(combatant: BattleCombatant, rng: RandomNumberGenerator) -> Array[Dictionary]:
	rolled_dice.clear()
	consumed_until_next_turn.clear()
	var total_dice := combatant.get_available_dice_count()
	for index in total_dice:
		var definition: DiceDefinition = null
		if index < combatant.dice_loadout.size():
			definition = combatant.dice_loadout[index]
		var face_value := rng.randi_range(1, 6)
		rolled_dice.append({
			"dice_id": _next_dice_id,
			"value": face_value,
			"state": "available",
			"definition": definition,
		})
		_next_dice_id += 1
	return get_available_dice()


func get_available_dice() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for die_data in rolled_dice:
		if die_data.get("state", "") == "available":
			available.append(die_data)
	return available


func get_dice_by_ids(dice_ids: Array[int]) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for dice_id in dice_ids:
		var die_data := _find_die_data(dice_id)
		if die_data.is_empty():
			return []
		selected.append(die_data)
	return selected


func consume_dice(dice_ids: Array[int]) -> void:
	for dice_id in dice_ids:
		var die_data := _find_die_data(dice_id)
		if die_data.is_empty():
			continue
		die_data["state"] = "consumed"
		consumed_until_next_turn.append(die_data)


func clear() -> void:
	rolled_dice.clear()
	consumed_until_next_turn.clear()


func _find_die_data(dice_id: int) -> Dictionary:
	for die_data in rolled_dice:
		if int(die_data.get("dice_id", -1)) == dice_id:
			return die_data
	return {}
