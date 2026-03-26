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
		printerr("Не удалось бросить кубы глобальной карты: отсутствует BoardController.")
		return []
	var definitions := GlobalMapDiceFactory.build_dice_definitions(profile)
	if definitions.is_empty():
		printerr("Не удалось бросить кубы глобальной карты: у игрока нет доступных кубов.")
		return []

	var requests: Array[DiceThrowRequest] = []
	for definition in definitions:
		var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
		request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
		request.metadata["owner"] = "global_map"
		request.metadata["definition"] = definition
		requests.append(request)
		print("брошен куб (%s)" % _format_face_values(definition))

	var dice_nodes := board_controller.throw_dice(requests)
	if dice_nodes.is_empty():
		printerr("Не удалось бросить кубы глобальной карты: BoardController не заспавнил ни одного куба.")
		return []
	var spawned_dice: Array[Dice] = []
	for node in dice_nodes:
		if not node is Dice:
			continue
		var dice := node as Dice
		dice.linear_velocity.y *= GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER
		spawned_dice.append(dice)
	if spawned_dice.is_empty():
		printerr("Не удалось бросить кубы глобальной карты: заспавненные ноды не являются Dice.")
	return spawned_dice


func _format_face_values(definition: DiceDefinition) -> String:
	if definition == null:
		return ""
	var values: PackedStringArray = PackedStringArray()
	for face in definition.faces:
		if face == null:
			continue
		values.append(face.text_value)
	return ", ".join(values)
