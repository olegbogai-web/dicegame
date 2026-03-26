extends RefCounted
class_name Player

const DiceDefinitionScript = preload("res://content/dice/resources/dice_definition.gd")
const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")

const GLOBAL_MAP_DICE_SKIN := preload("res://assets/dice_edges/bones_dice_skin.png")
const GLOBAL_MAP_MOB_ICON := preload("res://assets/global_map/swords.png")
const GLOBAL_MAP_EVENT_ICON := preload("res://assets/global_map/question_mark.png")

var player_id := ""
var base_stat: PlayerBaseStat
var current_hp := 0
var current_armor := 0
var dice_loadout: Array[DiceDefinition] = []
var global_map_dice_loadout: Array[DiceDefinition] = []
var ability_loadout: Array[AbilityDefinition] = []
var run_flags: Dictionary = {}
var metadata: Dictionary = {}


func _init(initial_base_stat: PlayerBaseStat = null) -> void:
	if initial_base_stat != null:
		apply_base_stat(initial_base_stat)


func apply_base_stat(next_base_stat: PlayerBaseStat) -> void:
	if next_base_stat == null:
		return
	base_stat = next_base_stat
	player_id = next_base_stat.player_id
	metadata = next_base_stat.metadata.duplicate(true)
	reset_for_run()


func reset_for_run() -> void:
	if base_stat == null:
		current_hp = 0
		current_armor = 0
		dice_loadout.clear()
		global_map_dice_loadout.clear()
		ability_loadout.clear()
		run_flags.clear()
		return
	current_hp = base_stat.get_resolved_starting_hp()
	current_armor = base_stat.starting_armor
	dice_loadout = base_stat.starting_dice.duplicate()
	global_map_dice_loadout = _build_default_global_map_dice_loadout(base_stat.base_cube_global_map)
	ability_loadout = base_stat.starting_abilities.duplicate()
	run_flags.clear()


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> int:
	var incoming_damage := maxi(amount, 0)
	var blocked_damage := mini(current_armor, incoming_damage)
	current_armor -= blocked_damage
	var hp_damage := incoming_damage - blocked_damage
	current_hp = maxi(current_hp - hp_damage, 0)
	return hp_damage


func heal(amount: int) -> int:
	if base_stat == null:
		return 0
	var resolved_amount := maxi(amount, 0)
	var previous_hp := current_hp
	current_hp = mini(current_hp + resolved_amount, base_stat.max_hp)
	return current_hp - previous_hp


func get_global_map_dice_loadout() -> Array[DiceDefinition]:
	return global_map_dice_loadout.duplicate()


func _build_default_global_map_dice_loadout(count: int) -> Array[DiceDefinition]:
	var resolved_count := maxi(count, 0)
	var dice_array: Array[DiceDefinition] = []
	for index in resolved_count:
		var definition := DiceDefinitionScript.new()
		definition.dice_name = "base_cube_global_map_%d" % index
		definition.texture = GLOBAL_MAP_DICE_SKIN
		definition.base_color = Color(0.96, 0.96, 0.96, 1.0)
		definition.faces = _build_default_global_map_faces()
		dice_array.append(definition)
	return dice_array


func _build_default_global_map_faces() -> Array[DiceFaceDefinition]:
	var faces: Array[DiceFaceDefinition] = []
	for _index in 5:
		var mob_face := DiceFaceDefinitionScript.new()
		mob_face.text_value = "swords"
		mob_face.content_type = DiceFaceDefinitionScript.ContentType.ICON
		mob_face.icon = GLOBAL_MAP_MOB_ICON
		faces.append(mob_face)
	var event_face := DiceFaceDefinitionScript.new()
	event_face.text_value = "question_mark"
	event_face.content_type = DiceFaceDefinitionScript.ContentType.ICON
	event_face.icon = GLOBAL_MAP_EVENT_ICON
	faces.append(event_face)
	return faces
