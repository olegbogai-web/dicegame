extends Room
class_name BattleRoom

const DEFAULT_FLOOR_TEXTURE := preload("res://assets/material/дерево.png")
const TEST_PLAYER_TEXTURE := preload("res://assets/entity/monsters/test_player.png")
const TEST_MONSTER_DEFINITION := preload("res://content/monsters/definitions/test_monster.tres")
const COMMON_ATTACK_ABILITY := preload("res://content/abilities/definitions/common_attack.tres")
const HEAL_ABILITY := preload("res://content/abilities/definitions/heal.tres")
const BASE_DICE := preload("res://content/resources/base_cube.tres")
const CombatEnums = preload("res://content/combat/resources/combat_enums.gd")
const CombatService = preload("res://content/combat/services/combat_service.gd")
const BattleState = preload("res://content/combat/runtime/battle_state.gd")
const BattleResult = preload("res://content/combat/runtime/battle_result.gd")

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
	var current_hp := 0
	var max_hp := 0

	func _init(
		next_sprite: Texture2D = null,
		next_abilities: Array[AbilityDefinition] = [],
		next_scale: Vector3 = Vector3.ONE,
		next_current_hp: int = 0,
		next_max_hp: int = 0
	) -> void:
		sprite = next_sprite
		abilities = _sanitize_abilities(next_abilities)
		base_scale = next_scale
		current_hp = maxi(next_current_hp, 0)
		max_hp = maxi(next_max_hp, 0)

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
var monster_definitions: Array[MonsterDefinition] = []
var monster_views: Array[CombatantViewData] = []
var left_floor_texture: Texture2D = DEFAULT_FLOOR_TEXTURE
var right_floor_texture: Texture2D = DEFAULT_FLOOR_TEXTURE
var combat_service: CombatService = CombatService.new()
var active_battle_state: BattleState
var last_battle_result: BattleResult


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
	if player_instance != null:
		abilities.assign(player_instance.ability_loadout)
		current_hp = player_instance.current_hp
		if player_instance.base_stat != null:
			max_hp = player_instance.base_stat.max_hp
	player_view = CombatantViewData.new(
		sprite,
		abilities,
		PLAYER_SPRITE_SCALE,
		current_hp,
		max_hp
	)
	_sync_active_battle_from_entities()


func set_monsters_from_definitions(next_monster_definitions: Array[MonsterDefinition]) -> void:
	monster_definitions.clear()
	monster_views.clear()
	for monster_definition in next_monster_definitions:
		if monster_definition == null:
			continue
		monster_definitions.append(monster_definition)
		monster_views.append(
			CombatantViewData.new(
				monster_definition.sprite,
				monster_definition.abilities,
				MONSTER_SPRITE_SCALE,
				monster_definition.max_health,
				monster_definition.max_health
			)
		)
	_sync_active_battle_from_entities()


func prepare_room() -> void:
	state.status = RoomEnums.RoomStatus.PREPARED
	battle_status = &"prepared"
	encounter_instance_data = {
		"room_id": room_id,
		"monster_ids": PackedStringArray(_get_monster_ids()),
	}


func enter_room() -> void:
	state.status = RoomEnums.RoomStatus.ENTERED
	state.visited = true
	battle_status = &"entered"


func start_battle() -> BattleState:
	if player_instance == null:
		player_instance = _build_test_player()
	if monster_definitions.is_empty():
		set_monsters_from_definitions([TEST_MONSTER_DEFINITION])
	if state.status == RoomEnums.RoomStatus.CREATED:
		prepare_room()
	if state.status == RoomEnums.RoomStatus.PREPARED:
		enter_room()
	state.status = RoomEnums.RoomStatus.ACTIVE
	battle_status = &"combat_active"
	active_battle_state = combat_service.create_battle_state(player_instance, monster_definitions, room_id)
	_sync_views_from_battle_state()
	return active_battle_state


func activate_player_ability(
	ability: AbilityDefinition,
	target_ids: PackedStringArray = PackedStringArray(),
	selected_dice_ids: Array[String] = []
) -> Dictionary:
	if active_battle_state == null:
		start_battle()
	var result := combat_service.activate_player_ability(active_battle_state, ability, target_ids, selected_dice_ids)
	_finalize_battle_if_needed()
	_sync_views_from_battle_state()
	return result


func end_player_turn() -> void:
	if active_battle_state == null or active_battle_state.is_finished:
		return
	combat_service.end_turn(active_battle_state, CombatEnums.TurnEndReason.MANUAL)
	combat_service.run_monsters_until_player_turn(active_battle_state)
	_finalize_battle_if_needed()
	_sync_views_from_battle_state()


func run_current_monster_turn() -> void:
	if active_battle_state == null or active_battle_state.is_finished:
		return
	combat_service.run_current_monster_turn(active_battle_state)
	_finalize_battle_if_needed()
	_sync_views_from_battle_state()


func get_active_turn_dice() -> Array:
	if active_battle_state == null or active_battle_state.turn_state == null:
		return []
	return active_battle_state.turn_state.get_available_dice()


func get_player_health_ratio() -> float:
	if player_view == null:
		return 0.0
	return player_view.get_health_ratio()


func get_monster_health_ratio(index: int) -> float:
	if index < 0 or index >= monster_views.size():
		return 0.0
	return monster_views[index].get_health_ratio()


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


func get_battle_result() -> BattleResult:
	return last_battle_result


func is_battle_active() -> bool:
	return active_battle_state != null and not active_battle_state.is_finished


func _finalize_battle_if_needed() -> void:
	if active_battle_state == null or not active_battle_state.is_finished:
		return
	last_battle_result = active_battle_state.result
	state.status = RoomEnums.RoomStatus.RESOLVING
	state.resolution_payload = {
		"battle_id": active_battle_state.battle_id,
		"outcome": last_battle_result.outcome,
		"reason": last_battle_result.reason,
		"surviving_ids": last_battle_result.surviving_ids,
		"defeated_ids": last_battle_result.defeated_ids,
	}
	if last_battle_result.outcome == CombatEnums.BattleOutcome.PLAYER_VICTORY:
		state.status = RoomEnums.RoomStatus.COMPLETED
		state.completed_successfully = true
		battle_status = &"completed"
	else:
		state.status = RoomEnums.RoomStatus.FAILED
		state.completed_successfully = false
		battle_status = &"failed"


func _sync_active_battle_from_entities() -> void:
	if active_battle_state == null or active_battle_state.is_finished:
		return
	_sync_views_from_battle_state()


func _sync_views_from_battle_state() -> void:
	if active_battle_state == null:
		return
	var player_runtime = active_battle_state.get_player()
	if player_runtime != null:
		player_view.current_hp = player_runtime.current_hp
		player_view.max_hp = player_runtime.max_hp
		if player_instance != null:
			player_instance.current_hp = player_runtime.current_hp
			player_instance.current_armor = player_runtime.armor
	monster_views.clear()
	for enemy in active_battle_state.get_enemies(true):
		var monster_definition := enemy.definition_ref as MonsterDefinition
		monster_views.append(
			CombatantViewData.new(
				monster_definition.sprite if monster_definition != null else null,
				enemy.abilities,
				MONSTER_SPRITE_SCALE,
				enemy.current_hp,
				enemy.max_hp
			)
		)


func _get_monster_ids() -> Array[String]:
	var ids: Array[String] = []
	for monster_definition in monster_definitions:
		if monster_definition != null:
			ids.append(monster_definition.monster_id)
	return ids


static func create_test_battle_room() -> BattleRoom:
	var room := BattleRoom.new()
	room.room_id = "test_battle_room"
	room.set_floor_textures(DEFAULT_FLOOR_TEXTURE, DEFAULT_FLOOR_TEXTURE)
	room.set_player_data(_build_test_player(), TEST_PLAYER_TEXTURE)
	room.set_monsters_from_definitions([TEST_MONSTER_DEFINITION])
	room.prepare_room()
	return room


static func _build_test_player() -> Player:
	var base_stat := PlayerBaseStat.new()
	base_stat.player_id = "test_player"
	base_stat.display_name = "Тестовый игрок"
	base_stat.max_hp = 30
	base_stat.starting_hp = 30
	base_stat.starting_armor = 0
	base_stat.starting_dice = [BASE_DICE, BASE_DICE, BASE_DICE]
	base_stat.starting_abilities = [COMMON_ATTACK_ABILITY, HEAL_ABILITY]
	return Player.new(base_stat)
