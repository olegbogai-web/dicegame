@tool
extends Resource
class_name PlayerBaseStat

const DEFAULT_MAX_HP := 30
const GLOBAL_MAP_SWORDS_ICON := preload("res://assets/global_map/swords.png")
const GLOBAL_MAP_EVENT_ICON := preload("res://assets/global_map/question_mark.png")
const GLOBAL_MAP_DICE_SKIN := preload("res://assets/dice_edges/bones_dice_skin.png")
const REWARD_ARTIFACT_ICON := preload("res://assets/dice_edges/artifact_+.png")
const REWARD_CUBE_ICON := preload("res://assets/dice_edges/cube_+.png")
const REWARD_CUBE_UP_ICON := preload("res://assets/dice_edges/cube_up.png")
const REWARD_CARD_UP_ICON := preload("res://assets/dice_edges/card_up.png")
const REWARD_MONEY_ICON := preload("res://assets/dice_edges/money.png")
const MONEY_DICE_SKIN := preload("res://assets/dice_edges/money_dice_skin.png")
const DiceDefinitionScript = preload("res://content/dice/resources/dice_definition.gd")
const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")

@export_category("Identity")
@export var player_id := ""
@export var display_name := "New Player"
@export var tags: PackedStringArray = PackedStringArray()

@export_category("Base Stats")
@export_range(1, 999, 1) var max_hp := DEFAULT_MAX_HP
@export_range(0, 999, 1) var starting_hp := DEFAULT_MAX_HP
@export_range(0, 999, 1) var starting_armor := 0
@export var starting_dice: Array[DiceDefinition] = []
@export var base_cube_global_map: Array[DiceDefinition] = []
@export var base_reward_cube: DiceDefinition
@export var base_money_cube: DiceDefinition
@export var starting_abilities: Array[AbilityDefinition] = []
@export var artifacts_base: Array[ArtifactDefinition] = []
@export var metadata: Dictionary = {}


func get_resolved_starting_hp() -> int:
	return clampi(starting_hp, 0, max_hp)


func is_valid_definition() -> bool:
	if player_id.is_empty() or display_name.is_empty() or max_hp <= 0:
		return false
	for dice_definition in starting_dice:
		if dice_definition == null:
			return false
	for global_map_dice_definition in get_resolved_base_cube_global_map():
		if global_map_dice_definition == null:
			return false
	if get_resolved_base_reward_cube() == null:
		return false
	if get_resolved_base_money_cube() == null:
		return false
	for ability_definition in starting_abilities:
		if ability_definition == null or not ability_definition.supports_owner(true):
			return false
	for artifact_definition in get_resolved_artifacts_base():
		if artifact_definition == null:
			return false
	return true


func get_resolved_base_cube_global_map() -> Array[DiceDefinition]:
	if not base_cube_global_map.is_empty():
		return base_cube_global_map
	return _build_default_base_cube_global_map()


func get_resolved_base_reward_cube() -> DiceDefinition:
	if base_reward_cube != null:
		return base_reward_cube
	return _build_default_reward_cube_definition()


func get_resolved_base_money_cube() -> DiceDefinition:
	if base_money_cube != null:
		return base_money_cube
	return _build_default_money_cube_definition()


func get_resolved_artifacts_base() -> Array[ArtifactDefinition]:
	if not artifacts_base.is_empty():
		return artifacts_base
	return _build_default_artifacts_base()


func _build_default_base_cube_global_map() -> Array[DiceDefinition]:
	var resolved: Array[DiceDefinition] = []
	for _index in 2:
		resolved.append(_build_global_map_dice_definition())
	return resolved


func _build_global_map_dice_definition() -> DiceDefinition:
	var dice_definition := DiceDefinitionScript.new()
	dice_definition.dice_name = "base_cube_global_map"
	dice_definition.texture = GLOBAL_MAP_DICE_SKIN
	dice_definition.base_color = Color(0.96, 0.96, 0.96, 1.0)
	dice_definition.faces = _build_global_map_faces()
	return dice_definition


func _build_global_map_faces() -> Array[DiceFaceDefinition]:
	var faces: Array[DiceFaceDefinition] = []
	for _index in 5:
		faces.append(_build_face("swords", GLOBAL_MAP_SWORDS_ICON))
	faces.append(_build_face("question_mark", GLOBAL_MAP_EVENT_ICON))
	return faces


func _build_default_reward_cube_definition() -> DiceDefinition:
	var dice_definition := DiceDefinitionScript.new()
	dice_definition.dice_name = "reward_cube"
	dice_definition.base_color = Color(0.76, 0.76, 0.76, 1.0)
	dice_definition.faces = [
		_build_face("card_up", REWARD_CARD_UP_ICON),
		_build_face("card_up", REWARD_CARD_UP_ICON),
		_build_face("card_up", REWARD_CARD_UP_ICON),
		_build_face("card_up", REWARD_CARD_UP_ICON),
		_build_face("card_up", REWARD_CARD_UP_ICON),
		_build_face("card_up", REWARD_CARD_UP_ICON),
	]
	return dice_definition


func _build_default_money_cube_definition() -> DiceDefinition:
	var dice_definition := DiceDefinitionScript.new()
	dice_definition.dice_name = "money_cube"
	dice_definition.texture = MONEY_DICE_SKIN
	dice_definition.base_color = Color(1.0, 0.96, 0.86, 1.0)
	dice_definition.faces = _build_default_money_faces()
	return dice_definition


func _build_default_money_faces() -> Array[DiceFaceDefinition]:
	var faces: Array[DiceFaceDefinition] = []
	for value in range(1, 7):
		faces.append(_build_money_face(str(value)))
	return faces


func _build_default_artifacts_base() -> Array[ArtifactDefinition]:
	return []


func _build_money_face(value: String) -> DiceFaceDefinition:
	var face := DiceFaceDefinitionScript.new()
	face.text_value = value
	face.content_type = DiceFaceDefinitionScript.ContentType.TEXT
	face.text_color = Color(1.0, 0.95, 0.16, 1.0)
	face.text_outline_size = 12
	face.text_outline_color = Color(0.67, 0.22, 0.0, 1.0)
	return face


func _build_face(value: String, icon: Texture2D) -> DiceFaceDefinition:
	var face := DiceFaceDefinitionScript.new()
	face.text_value = value
	face.content_type = DiceFaceDefinitionScript.ContentType.ICON
	face.icon = icon
	face.overlay_tint = Color(1.0, 1.0, 1.0, 1.0)
	return face
