extends RefCounted
class_name GlobalMapDiceRollService

const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const GLOBAL_MAP_ROLL_DELAY_SECONDS := 0.75
const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3(0.33333334, 0.33333334, 0.33333334)
const GLOBAL_MAP_THROW_HEIGHT_MULTIPLIER := 2.0


func schedule_pending_roll(owner: Node, board) -> void:
	if owner == null or board == null:
		return
	if not GlobalMapRuntimeState.has_pending_global_map_roll():
		return
	owner.call_deferred("_run_global_map_pending_roll", board)


func run_pending_roll(owner: Node, board) -> void:
	if owner == null or board == null:
		return
	if not GlobalMapRuntimeState.has_pending_global_map_roll():
		return
	await owner.get_tree().create_timer(GLOBAL_MAP_ROLL_DELAY_SECONDS).timeout
	var payload := GlobalMapRuntimeState.consume_pending_global_map_roll()
	if payload.is_empty():
		return
	var definitions := payload.get("definitions", []) as Array
	var requests: Array[DiceThrowRequest] = []
	for definition in definitions:
		if not definition is DiceDefinition:
			continue
		var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
		request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
		request.metadata["owner"] = "global_map"
		request.metadata["definition"] = definition
		requests.append(request)
	if requests.is_empty():
		return
	var spawned_dice := board.throw_dice(requests)
	for dice in spawned_dice:
		if not is_instance_valid(dice):
			continue
		dice.linear_velocity.y *= GLOBAL_MAP_THROW_HEIGHT_MULTIPLIER
