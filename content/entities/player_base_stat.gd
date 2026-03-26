@tool
extends Resource
class_name PlayerBaseStat

const DEFAULT_MAX_HP := 30
const DiceDefinitionScript = preload("res://content/dice/resources/dice_definition.gd")
const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")
const GLOBAL_MAP_MOB_ICON := preload("res://assets/global_map/swords.png")
const GLOBAL_MAP_EVENT_ICON := preload("res://assets/global_map/question_mark.png")
const GLOBAL_MAP_DICE_SKIN := preload("res://assets/dice_edges/bones_dice_skin.png")

@export_category("Identity")
@export var player_id := ""
@export var display_name := "New Player"
@export var tags: PackedStringArray = PackedStringArray()

@export_category("Base Stats")
@export_range(1, 999, 1) var max_hp := DEFAULT_MAX_HP
@export_range(0, 999, 1) var starting_hp := DEFAULT_MAX_HP
@export_range(0, 999, 1) var starting_armor := 0
@export var starting_dice: Array[DiceDefinition] = []
@export var starting_abilities: Array[AbilityDefinition] = []
@export var base_cube_global_map: DiceDefinition
@export_range(0, 99, 1) var base_cube_global_map_count := 2
@export var metadata: Dictionary = {}


func get_resolved_starting_hp() -> int:
	return clampi(starting_hp, 0, max_hp)


func is_valid_definition() -> bool:
	if player_id.is_empty() or display_name.is_empty() or max_hp <= 0:
		return false
	for dice_definition in starting_dice:
		if dice_definition == null:
			return false
	for ability_definition in starting_abilities:
		if ability_definition == null or not ability_definition.supports_owner(true):
			return false
	return true


func build_base_cube_global_map_descriptions() -> Array[DiceDefinition]:
	var resolved_base_cube := base_cube_global_map
	if resolved_base_cube == null:
		resolved_base_cube = _build_default_base_cube_global_map()
	var result: Array[DiceDefinition] = []
	for _index in range(maxi(base_cube_global_map_count, 0)):
		result.append(resolved_base_cube.duplicate(true))
	return result


func _build_default_base_cube_global_map() -> DiceDefinition:
	var definition := DiceDefinitionScript.new()
	definition.dice_name = "base_cube_global_map"
	definition.texture = GLOBAL_MAP_DICE_SKIN
	definition.base_color = Color(0.96, 0.96, 0.96, 1.0)
	definition.size_multiplier = Vector3.ONE
	definition.faces = _build_default_base_cube_global_map_faces()
	return definition


func _build_default_base_cube_global_map_faces() -> Array[DiceFaceDefinition]:
	var faces: Array[DiceFaceDefinition] = []
	for _index in range(5):
		var mob_face := DiceFaceDefinitionScript.new()
		mob_face.text_value = "mob"
		mob_face.content_type = DiceFaceDefinitionScript.ContentType.ICON
		mob_face.icon = GLOBAL_MAP_MOB_ICON
		faces.append(mob_face)
	var event_face := DiceFaceDefinitionScript.new()
	event_face.text_value = "event"
	event_face.content_type = DiceFaceDefinitionScript.ContentType.ICON
	event_face.icon = GLOBAL_MAP_EVENT_ICON
	faces.append(event_face)
	return faces
