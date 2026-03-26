extends RefCounted
class_name GlobalMapRuntimeState

const COMMON_ATTACK_ABILITY := preload("res://content/abilities/definitions/common_attack.tres")
const HEAL_ABILITY := preload("res://content/abilities/definitions/heal.tres")
const GLOBAL_MAP_DICE_SKIN := preload("res://assets/dice_edges/bones_dice_skin.png")
const GLOBAL_MAP_MOB_ICON := preload("res://assets/global_map/swords.png")
const GLOBAL_MAP_EVENT_ICON := preload("res://assets/global_map/question_mark.png")
const BASE_BATTLE_DICE := preload("res://content/resources/base_cube.tres")
const DiceDefinitionScript = preload("res://content/dice/resources/dice_definition.gd")
const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")

static var _has_persisted_snapshot := false
static var _persisted_snapshot: Dictionary = {}
static var _player_instance: Player

var is_transition_in_progress := false
var event_reached := false
var hero_move_started := false


static func save_snapshot(snapshot: Dictionary) -> void:
	_persisted_snapshot = snapshot.duplicate(true)
	_has_persisted_snapshot = true


static func has_snapshot() -> bool:
	return _has_persisted_snapshot


static func load_snapshot() -> Dictionary:
	return _persisted_snapshot.duplicate(true)


static func clear_snapshot() -> void:
	_persisted_snapshot.clear()
	_has_persisted_snapshot = false


static func get_player_instance() -> Player:
	if _player_instance == null:
		_player_instance = _build_test_player()
	return _player_instance


static func _build_test_player() -> Player:
	var base_stat := PlayerBaseStat.new()
	base_stat.player_id = "test_player"
	base_stat.display_name = "Тестовый игрок"
	base_stat.max_hp = 30
	base_stat.starting_hp = 30
	base_stat.starting_armor = 0
	base_stat.starting_abilities = [COMMON_ATTACK_ABILITY, HEAL_ABILITY]
	base_stat.starting_dice = [BASE_BATTLE_DICE, BASE_BATTLE_DICE, BASE_BATTLE_DICE]
	base_stat.base_cube_global_map = [
		_build_base_cube_global_map(),
		_build_base_cube_global_map(),
	]
	return Player.new(base_stat)


static func _build_base_cube_global_map() -> DiceDefinition:
	var definition := DiceDefinitionScript.new()
	definition.dice_name = "base_cube_global_map"
	definition.size_multiplier = Vector3.ONE
	definition.base_color = Color(1.0, 1.0, 1.0, 1.0)
	definition.texture = GLOBAL_MAP_DICE_SKIN
	definition.faces = []
	for _index in range(5):
		definition.faces.append(_build_global_map_face("swords", GLOBAL_MAP_MOB_ICON))
	definition.faces.append(_build_global_map_face("question_mark", GLOBAL_MAP_EVENT_ICON))
	return definition


static func _build_global_map_face(face_text: String, icon: Texture2D) -> DiceFaceDefinition:
	var face := DiceFaceDefinitionScript.new()
	face.text_value = face_text
	face.content_type = DiceFaceDefinitionScript.ContentType.ICON
	face.icon = icon
	face.overlay_tint = Color(1.0, 1.0, 1.0, 1.0)
	return face
