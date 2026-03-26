@tool
extends Resource
class_name GlobalMapCubeDefinition

const DEFAULT_CUBE_SKIN := preload("res://assets/dice_edges/bones_dice_skin.png")
const DEFAULT_MOB_ICON := preload("res://assets/global_map/swords.png")
const DEFAULT_EVENT_ICON := preload("res://assets/global_map/question_mark.png")
const FACE_COUNT := 6

@export_range(1, 99, 1) var cube_count := 1
@export var cube_skin: Texture2D = DEFAULT_CUBE_SKIN
@export var face_icons: Array[Texture2D] = []


func duplicate_for_runtime() -> GlobalMapCubeDefinition:
	var runtime_copy := GlobalMapCubeDefinition.new()
	runtime_copy.cube_count = maxi(cube_count, 1)
	runtime_copy.cube_skin = cube_skin
	runtime_copy.face_icons = face_icons.duplicate()
	return runtime_copy


func get_resolved_face_icons() -> Array[Texture2D]:
	var resolved_icons: Array[Texture2D] = []
	for icon in face_icons:
		if icon != null:
			resolved_icons.append(icon)
	while resolved_icons.size() < FACE_COUNT - 1:
		resolved_icons.append(DEFAULT_MOB_ICON)
	resolved_icons.append(DEFAULT_EVENT_ICON)
	return resolved_icons.slice(0, FACE_COUNT)
