extends RefCounted
class_name GlobalMapDiceRollService

const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3(5.0, 5.0, 5.0)
const GLOBAL_MAP_THROW_HEIGHT_MULTIPLIER := 4.0


func roll_from_player(board: BoardController, player: Player) -> Array[Dice]:
	if board == null or player == null:
		return []
	if player.runtime_cube_global_map.is_empty():
		return []

	var requests: Array[DiceThrowRequest] = []
	for dice_definition in player.runtime_cube_global_map:
		if dice_definition == null:
			continue
		var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
		request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
		request.metadata["owner"] = "global_map"
		request.metadata["definition"] = dice_definition
		requests.append(request)

	if requests.is_empty():
		return []

	var dice_nodes := board.throw_dice(requests)
	var global_map_dice: Array[Dice] = []
	for dice_node in dice_nodes:
		if not dice_node is Dice:
			continue
		var runtime_dice := dice_node as Dice
		runtime_dice.linear_velocity.y *= GLOBAL_MAP_THROW_HEIGHT_MULTIPLIER
		global_map_dice.append(runtime_dice)
	return global_map_dice
