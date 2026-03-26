extends RefCounted
class_name GlobalMapDiceRollService

const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const GlobalMapDiceFactory = preload("res://content/global_map/dice/global_map_dice_factory.gd")
const GlobalMapDiceProfile = preload("res://content/global_map/dice/global_map_dice_profile.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")

const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3(0.3333, 0.3333, 0.3333)
const GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER := 2.0


func throw_global_map_dice(board_controller: BoardController, profile: GlobalMapDiceProfile) -> Array[Dice]:
	if board_controller == null:
		return []
	var definitions := GlobalMapDiceFactory.build_dice_definitions(profile)
	if definitions.is_empty():
		return []

	var requests: Array[DiceThrowRequest] = []
	for definition in definitions:
		var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
		request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
		request.metadata["owner"] = "global_map"
		request.metadata["definition"] = definition
		requests.append(request)

	var dice_nodes := board_controller.throw_dice(requests)
	var spawned_dice: Array[Dice] = []
	for node in dice_nodes:
		if not node is Dice:
			continue
		var dice := node as Dice
		dice.linear_velocity.y *= GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER
		spawned_dice.append(dice)
	return spawned_dice
