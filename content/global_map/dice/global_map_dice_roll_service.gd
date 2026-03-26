extends RefCounted
class_name GlobalMapDiceRollService

const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const DiceDefinitionScript = preload("res://content/dice/resources/dice_definition.gd")
const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")
const GlobalMapCubeDefinition = preload("res://content/entities/resources/global_map_cube_definition.gd")

const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)
const GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER := 2.0
const GLOBAL_MAP_DICE_MASS := 1.0
const DEFAULT_FACE_TINT := Color(1.0, 1.0, 1.0, 1.0)


static func build_throw_requests(player: Player, base_dice_scene: PackedScene) -> Array[DiceThrowRequest]:
	if base_dice_scene == null:
		return []
	var requests: Array[DiceThrowRequest] = []
	var runtime_cubes := _resolve_runtime_cube_list(player)
	for runtime_cube in runtime_cubes:
		if runtime_cube == null:
			continue
		var resolved_count := maxi(runtime_cube.cube_count, 0)
		for _index in range(resolved_count):
			var request := DiceThrowRequestScript.create(base_dice_scene)
			request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
			request.mass = GLOBAL_MAP_DICE_MASS
			request.metadata["owner"] = &"global_map"
			request.metadata["definition"] = _build_dice_definition(runtime_cube)
			requests.append(request)
	return requests


static func apply_throw_height_multiplier(dice_nodes: Array[RigidBody3D]) -> void:
	for dice_node in dice_nodes:
		if dice_node == null or not is_instance_valid(dice_node):
			continue
		dice_node.linear_velocity.y *= GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER


static func _resolve_runtime_cube_list(player: Player) -> Array[GlobalMapCubeDefinition]:
	if player == null:
		return []
	if not player.runtime_cube_global_map.is_empty():
		return player.runtime_cube_global_map
	if player.base_stat != null:
		return player.base_stat.base_cube_global_map
	return []


static func _build_dice_definition(cube_definition: GlobalMapCubeDefinition) -> DiceDefinition:
	var definition := DiceDefinitionScript.new()
	definition.dice_name = "global_map_cube"
	definition.texture = cube_definition.cube_skin
	definition.faces = _build_faces(cube_definition)
	return definition


static func _build_faces(cube_definition: GlobalMapCubeDefinition) -> Array[DiceFaceDefinition]:
	var faces: Array[DiceFaceDefinition] = []
	for icon in cube_definition.get_resolved_face_icons():
		var face := DiceFaceDefinitionScript.new()
		face.content_type = DiceFaceDefinitionScript.ContentType.ICON
		face.icon = icon
		face.overlay_tint = DEFAULT_FACE_TINT
		faces.append(face)
	return faces
