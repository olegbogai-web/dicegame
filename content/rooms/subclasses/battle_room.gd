extends Room
class_name BattleRoom

const DEFAULT_FLOOR_TEXTURE := preload("res://assets/material/дерево.png")
const TEST_PLAYER_TEXTURE := preload("res://assets/entity/monsters/test_player.png")
const TEST_MONSTER_DEFINITION := preload("res://content/monsters/definitions/test_monster.tres")
const COMMON_ATTACK_ABILITY := preload("res://content/abilities/definitions/common_attack.tres")
const HEAL_ABILITY := preload("res://content/abilities/definitions/heal.tres")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const BattleTurnRuntime = preload("res://content/combat/runtime/battle_turn_runtime.gd")
const BattleEffectRuntime = preload("res://content/combat/runtime/battle_effect_runtime.gd")

const PLAYER_SPRITE_POSITION := Vector3(-3.0, 0.01, -2.5)
const PLAYER_SPRITE_SCALE := Vector3(2.0, 2.0, 2.0)
const MONSTER_SPRITE_POSITION := Vector3(3.0, 0.01, -2.5)
const MONSTER_SPRITE_SCALE := Vector3(2.0, 2.0, 2.0)
const PLAYER_ABILITY_FRAME_POSITION := Vector3(-7.5, 0.01, 0.0)
const MONSTER_ABILITY_FRAME_POSITION := Vector3(7.4, 0.01, 0.0)
const STACK_SPACING_Z := 1.85
const DICE_PLACE_Z_POSITIONS := [-0.557, -0.007, 0.55]


class CombatantViewData:
	extends RefCounted

	var sprite: Texture2D
	var abilities: Array[AbilityDefinition] = []
	var base_scale: Vector3 = Vector3.ONE
	var current_hp := 0
	var max_hp := 0
	var dice_count := 0
	var ai_profile: MonsterAiProfile

	func _init(
		next_sprite: Texture2D = null,
		next_abilities: Array[AbilityDefinition] = [],
		next_scale: Vector3 = Vector3.ONE,
		next_current_hp: int = 0,
		next_max_hp: int = 0,
		next_dice_count: int = 0,
		next_ai_profile: MonsterAiProfile = null
	) -> void:
		sprite = next_sprite
		abilities = _sanitize_abilities(next_abilities)
		base_scale = next_scale
		current_hp = maxi(next_current_hp, 0)
		max_hp = maxi(next_max_hp, 0)
		dice_count = maxi(next_dice_count, 0)
		ai_profile = next_ai_profile

	static func _sanitize_abilities(next_abilities: Array[AbilityDefinition]) -> Array[AbilityDefinition]:
		var sanitized: Array[AbilityDefinition] = []
		for ability in next_abilities:
			if ability != null:
				sanitized.append(ability)
		return sanitized

	func get_health_ratio() -> float:
		if max_hp <= 0:
			return 0.0
		return clampf(float(current_hp) / float(max_hp), 0.0, 1.0)

	func is_alive() -> bool:
		return current_hp > 0

	func take_damage(amount: int) -> int:
		var resolved_damage := maxi(amount, 0)
		current_hp = maxi(current_hp - resolved_damage, 0)
		return resolved_damage

	func heal(amount: int) -> int:
		var resolved_heal := maxi(amount, 0)
		var previous_hp := current_hp
		current_hp = mini(current_hp + resolved_heal, max_hp)
		return current_hp - previous_hp


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
var current_turn_owner: StringName = &"none"
var current_monster_turn_index := -1
var turn_counter := 0
var battle_result: StringName = &"none"


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
	var current_hp := 0
	var max_hp := 0
	var dice_count := 0
	var ai_profile: MonsterAiProfile
	if player_instance != null:
		abilities.assign(player_instance.ability_loadout)
		current_hp = player_instance.current_hp
		dice_count = player_instance.dice_loadout.size()
		if player_instance.base_stat != null:
			max_hp = player_instance.base_stat.max_hp
	player_view = CombatantViewData.new(
		sprite,
		abilities,
		PLAYER_SPRITE_SCALE,
		current_hp,
		max_hp,
		dice_count
	)
	_reset_battle_progression()


func set_monsters_from_definitions(next_monster_definitions: Array[MonsterDefinition]) -> void:
	monster_views.clear()
	for monster_definition in next_monster_definitions:
		if monster_definition == null:
			continue
		monster_views.append(
			CombatantViewData.new(
				monster_definition.sprite,
				monster_definition.abilities,
				MONSTER_SPRITE_SCALE,
				monster_definition.max_health,
				monster_definition.max_health,
				monster_definition.dice_count,
				monster_definition.ai_profile
			)
		)
	_reset_battle_progression()


func get_player_health_ratio() -> float:
	if player_view == null:
		return 0.0
	return player_view.get_health_ratio()


func get_player_health_values() -> Vector2i:
	if player_view == null:
		return Vector2i.ZERO
	return Vector2i(player_view.current_hp, player_view.max_hp)


func get_monster_health_ratio(index: int) -> float:
	if index < 0 or index >= monster_views.size():
		return 0.0
	return monster_views[index].get_health_ratio()


func get_monster_health_values(index: int) -> Vector2i:
	if index < 0 or index >= monster_views.size() or monster_views[index] == null:
		return Vector2i.ZERO
	var monster_view := monster_views[index]
	return Vector2i(monster_view.current_hp, monster_view.max_hp)


func get_player_abilities() -> Array[AbilityDefinition]:
	return player_view.abilities


func get_monster_abilities() -> Array[AbilityDefinition]:
	var resolved: Array[AbilityDefinition] = []
	for entry in get_monster_ability_entries():
		var ability := entry.get("ability") as AbilityDefinition
		if ability != null:
			resolved.append(ability)
	return resolved


func get_monster_view(index: int) -> CombatantViewData:
	if index < 0 or index >= monster_views.size():
		return null
	return monster_views[index]


func get_monster_ability_entries() -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for monster_index in monster_views.size():
		var monster_view := monster_views[monster_index]
		if monster_view == null:
			continue
		for ability_index in monster_view.abilities.size():
			var ability := monster_view.abilities[ability_index]
			if ability == null:
				continue
			resolved.append({
				"monster_index": monster_index,
				"ability_index": ability_index,
				"ability": ability,
			})
	return resolved


func get_required_dice_slots(ability: AbilityDefinition) -> int:
	return mini(BattleAbilityRuntime.get_required_dice_count(ability), 3)


func can_target_player() -> bool:
	return player_view != null and player_view.is_alive()


func can_target_monster(index: int) -> bool:
	if index < 0 or index >= monster_views.size():
		return false
	return monster_views[index] != null and monster_views[index].is_alive()


func get_living_monster_indexes() -> Array[int]:
	var indexes: Array[int] = []
	for index in monster_views.size():
		if can_target_monster(index):
			indexes.append(index)
	return indexes


func get_monster_turn_order() -> Array[int]:
	var living_indexes := get_living_monster_indexes()
	living_indexes.sort_custom(func(a: int, b: int) -> bool:
		var left_dice := monster_views[a].dice_count if a >= 0 and a < monster_views.size() and monster_views[a] != null else 0
		var right_dice := monster_views[b].dice_count if b >= 0 and b < monster_views.size() and monster_views[b] != null else 0
		if left_dice == right_dice:
			return a < b
		return left_dice > right_dice
	)
	return living_indexes


func start_battle() -> Dictionary:
	return BattleTurnRuntime.start_battle(self)


func get_current_turn_context() -> Dictionary:
	return BattleTurnRuntime.get_current_turn_context(self)


func get_current_turn_dice_count() -> int:
	return BattleTurnRuntime.get_current_turn_dice_count(self)


func is_player_turn() -> bool:
	return BattleTurnRuntime.is_player_turn(self)


func is_monster_turn() -> bool:
	return BattleTurnRuntime.is_monster_turn(self)


func is_battle_over() -> bool:
	return BattleTurnRuntime.is_battle_over(self)


func advance_turn() -> Dictionary:
	return BattleTurnRuntime.advance_turn(self)


func activate_player_ability(ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	return activate_current_turn_ability(ability, target_descriptor)


func activate_current_turn_ability(ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	return BattleEffectRuntime.activate_current_turn_ability(self, ability, target_descriptor)


func is_valid_room() -> bool:
	return super.is_valid_room() and room_type == RoomEnums.RoomType.BATTLE


func _reset_battle_progression() -> void:
	BattleTurnRuntime.reset_battle_progression(self)


func _update_battle_result_if_finished() -> bool:
	return BattleTurnRuntime.update_battle_result_if_finished(self)


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
	base_stat.starting_dice = [
		preload("res://content/resources/base_cube.tres"),
		preload("res://content/resources/base_cube.tres"),
		preload("res://content/resources/base_cube.tres"),
	]
	return Player.new(base_stat)
