extends Room
class_name BattleRoom

const DEFAULT_FLOOR_TEXTURE := preload("res://assets/material/дерево.png")
const TEST_PLAYER_TEXTURE := preload("res://assets/entity/monsters/test_player.png")
const TEST_MONSTER_DEFINITION := preload("res://content/monsters/definitions/test_monster.tres")
const COMMON_ATTACK_ABILITY := preload("res://content/abilities/definitions/common_attack.tres")
const HEAL_ABILITY := preload("res://content/abilities/definitions/heal.tres")

const PLAYER_SPRITE_POSITION := Vector3(-6.7, 0.41, 0.0)
const PLAYER_SPRITE_SCALE := Vector3(1.2, 1.2, 1.2)
const MONSTER_SPRITE_POSITION := Vector3(6.7, 0.41, 0.0)
const MONSTER_SPRITE_SCALE := Vector3(1.25, 1.25, 1.25)
const PLAYER_ABILITY_FRAME_POSITION := Vector3(-4.25, 0.405, 0.0)
const MONSTER_ABILITY_FRAME_POSITION := Vector3(4.25, 0.405, 0.0)
const STACK_SPACING_Z := 1.85
const DICE_PLACE_Z_POSITIONS := [-0.557, -0.007, 0.55]


class CombatantViewData:
	extends RefCounted

	var sprite: Texture2D
	var abilities: Array[AbilityDefinition] = []
	var base_scale: Vector3 = Vector3.ONE

	func _init(
		next_sprite: Texture2D = null,
		next_abilities: Array[AbilityDefinition] = [],
		next_scale: Vector3 = Vector3.ONE
	) -> void:
		sprite = next_sprite
		abilities = _sanitize_abilities(next_abilities)
		base_scale = next_scale

	static func _sanitize_abilities(next_abilities: Array[AbilityDefinition]) -> Array[AbilityDefinition]:
		var sanitized: Array[AbilityDefinition] = []
		for ability in next_abilities:
			if ability != null:
				sanitized.append(ability)
		return sanitized


func _init() -> void:
	super()
	room_type = RoomEnums.RoomType.BATTLE


var battle_definition: BattleRoomDefinition
var encounter_definition_ref: StringName
var monster_pool_ref: StringName
var encounter_generation_ref: StringName
var battle_rule_refs: PackedStringArray = PackedStringArray()
var battle_start_ref: StringName
var battle_completion_ref: StringName
var battle_visual_ref: StringName
var encounter_instance_data: Dictionary = {}
var battle_status: StringName = &"not_started"
var reward_refs: PackedStringArray = PackedStringArray()

var player_instance: Player
var player_view: CombatantViewData = CombatantViewData.new()
var monster_views: Array[CombatantViewData] = []
var left_floor_texture: Texture2D = DEFAULT_FLOOR_TEXTURE
var right_floor_texture: Texture2D = DEFAULT_FLOOR_TEXTURE


func apply_battle_definition(definition: BattleRoomDefinition) -> void:
	if definition == null:
		return
	battle_definition = definition
	apply_definition(definition)
	room_type = RoomEnums.RoomType.BATTLE
	encounter_definition_ref = definition.encounter_definition_ref
	monster_pool_ref = definition.monster_pool_ref
	encounter_generation_ref = definition.encounter_generation_ref
	battle_rule_refs = definition.battle_rule_refs.duplicate()
	battle_start_ref = definition.battle_start_ref
	battle_completion_ref = definition.battle_completion_ref
	battle_visual_ref = definition.battle_visual_ref


func set_floor_textures(left_texture: Texture2D, right_texture: Texture2D) -> void:
	left_floor_texture = left_texture if left_texture != null else DEFAULT_FLOOR_TEXTURE
	right_floor_texture = right_texture if right_texture != null else DEFAULT_FLOOR_TEXTURE


func set_player_data(player: Player, sprite: Texture2D) -> void:
	player_instance = player
	var abilities: Array[AbilityDefinition] = []
	if player_instance != null:
		abilities.assign(player_instance.ability_loadout)
	player_view = CombatantViewData.new(sprite, abilities, PLAYER_SPRITE_SCALE)


func set_monsters_from_definitions(monster_definitions: Array[MonsterDefinition]) -> void:
	monster_views.clear()
	for monster_definition in monster_definitions:
		if monster_definition == null:
			continue
		monster_views.append(
			CombatantViewData.new(
				monster_definition.sprite,
				monster_definition.abilities,
				MONSTER_SPRITE_SCALE
			)
		)


func get_player_abilities() -> Array[AbilityDefinition]:
	return player_view.abilities


func get_monster_abilities() -> Array[AbilityDefinition]:
	var resolved: Array[AbilityDefinition] = []
	for monster_view in monster_views:
		for ability in monster_view.abilities:
			if ability != null:
				resolved.append(ability)
	return resolved


func get_required_dice_slots(ability: AbilityDefinition) -> int:
	if ability == null or ability.cost == null or not ability.cost.requires_dice():
		return 0

	var total_required := 0
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		total_required += maxi(dice_condition.required_count, 0)
	return mini(total_required, 3)


func is_valid_room() -> bool:
	return super.is_valid_room() and room_type == RoomEnums.RoomType.BATTLE


static func create_test_battle_room() -> BattleRoom:
	var room := BattleRoom.new()
	room.room_id = "test_battle_room"
	room.set_floor_textures(DEFAULT_FLOOR_TEXTURE, DEFAULT_FLOOR_TEXTURE)
	room.set_player_data(_build_test_player(), TEST_PLAYER_TEXTURE)
	room.set_monsters_from_definitions([TEST_MONSTER_DEFINITION])
	return room


static func _build_test_player() -> Player:
	var base_stat := PlayerBaseStat.new()
	base_stat.player_id = "test_player"
	base_stat.display_name = "Тестовый игрок"
	base_stat.max_hp = 30
	base_stat.starting_hp = 30
	base_stat.starting_armor = 0
	base_stat.starting_abilities = [COMMON_ATTACK_ABILITY, HEAL_ABILITY]
	return Player.new(base_stat)
