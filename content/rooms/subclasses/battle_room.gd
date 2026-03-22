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
	var current_hp := 0
	var max_hp := 0
	var dice_count := 0
	var combatant_id: StringName = &""
	var ai_profile_id: StringName = &""

	func _init(
		next_sprite: Texture2D = null,
		next_abilities: Array[AbilityDefinition] = [],
		next_scale: Vector3 = Vector3.ONE,
		next_current_hp: int = 0,
		next_max_hp: int = 0,
		next_dice_count: int = 0,
		next_combatant_id: StringName = &"",
		next_ai_profile_id: StringName = &""
	) -> void:
		sprite = next_sprite
		abilities = _sanitize_abilities(next_abilities)
		base_scale = next_scale
		current_hp = maxi(next_current_hp, 0)
		max_hp = maxi(next_max_hp, 0)
		dice_count = maxi(next_dice_count, 0)
		combatant_id = next_combatant_id
		ai_profile_id = next_ai_profile_id

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
		dice_count,
		&"player",
		&""
	)
	_reset_battle_progression()


func set_monsters_from_definitions(monster_definitions: Array[MonsterDefinition]) -> void:
	monster_views.clear()
	for monster_definition in monster_definitions:
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
				StringName(monster_definition.monster_id),
				monster_definition.ai_profile_id
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
	for monster_view in monster_views:
		for ability in monster_view.abilities:
			if ability != null:
				resolved.append(ability)
	return resolved


func get_monster_abilities_for(index: int) -> Array[AbilityDefinition]:
	if index < 0 or index >= monster_views.size() or monster_views[index] == null:
		return []
	return monster_views[index].abilities


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


func get_monster_ai_profile_id(index: int) -> StringName:
	if index < 0 or index >= monster_views.size() or monster_views[index] == null:
		return &""
	return monster_views[index].ai_profile_id


func find_monster_ability_by_id(index: int, ability_id: StringName) -> AbilityDefinition:
	for ability in get_monster_abilities_for(index):
		if ability != null and StringName(ability.ability_id) == ability_id:
			return ability
	return null


func get_required_dice_slots(ability: AbilityDefinition) -> int:
	if ability == null or ability.cost == null or not ability.cost.requires_dice():
		return 0

	var total_required := 0
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		total_required += maxi(dice_condition.required_count, 0)
	return mini(total_required, 3)


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
	_reset_battle_progression()
	if _update_battle_result_if_finished():
		return get_current_turn_context()
	battle_status = &"active"
	current_turn_owner = &"player"
	current_monster_turn_index = -1
	turn_counter = 1
	return get_current_turn_context()


func get_current_turn_context() -> Dictionary:
	return {
		"battle_status": battle_status,
		"battle_result": battle_result,
		"turn_counter": turn_counter,
		"owner": current_turn_owner,
		"monster_index": current_monster_turn_index,
		"dice_count": get_current_turn_dice_count(),
	}


func get_current_turn_dice_count() -> int:
	if current_turn_owner == &"player":
		return player_view.dice_count if player_view != null else 0
	if current_turn_owner == &"monster" and can_target_monster(current_monster_turn_index):
		return monster_views[current_monster_turn_index].dice_count
	return 0


func is_player_turn() -> bool:
	return battle_status == &"active" and current_turn_owner == &"player"


func is_monster_turn() -> bool:
	return battle_status == &"active" and current_turn_owner == &"monster"


func is_battle_over() -> bool:
	return battle_status == &"victory" or battle_status == &"defeat"


func advance_turn() -> Dictionary:
	if _update_battle_result_if_finished():
		return get_current_turn_context()
	if battle_status != &"active":
		return get_current_turn_context()

	if current_turn_owner == &"player":
		var monster_order := get_monster_turn_order()
		if monster_order.is_empty():
			_update_battle_result_if_finished()
			return get_current_turn_context()
		current_turn_owner = &"monster"
		current_monster_turn_index = monster_order[0]
		return get_current_turn_context()

	if current_turn_owner == &"monster":
		var current_order := get_monster_turn_order()
		var next_order_position := current_order.find(current_monster_turn_index) + 1
		if next_order_position > 0 and next_order_position < current_order.size():
			current_monster_turn_index = current_order[next_order_position]
			return get_current_turn_context()
		current_turn_owner = &"player"
		current_monster_turn_index = -1
		turn_counter += 1
		return get_current_turn_context()

	return start_battle()


func activate_player_ability(ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	if ability == null or not is_player_turn() or is_battle_over():
		return {
			"success": false,
			"affected_targets": [],
			"battle_finished": is_battle_over(),
		}

	var affected_targets: Array[Dictionary] = []
	for effect in ability.effects:
		if effect == null:
			continue
		var effect_targets := _resolve_effect_targets(target_descriptor)
		for effect_target in effect_targets:
			if _apply_effect_to_target(effect, effect_target):
				affected_targets.append(effect_target)

	_update_battle_result_if_finished()
	return {
		"success": true,
		"affected_targets": affected_targets,
		"battle_finished": is_battle_over(),
		"battle_result": battle_result,
	}


func activate_monster_ability(monster_index: int, ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	if ability == null or not is_monster_turn() or is_battle_over():
		return {
			"success": false,
			"affected_targets": [],
			"battle_finished": is_battle_over(),
		}
	if monster_index != current_monster_turn_index or not can_target_monster(monster_index):
		return {
			"success": false,
			"affected_targets": [],
			"battle_finished": is_battle_over(),
		}

	var affected_targets: Array[Dictionary] = []
	for effect in ability.effects:
		if effect == null:
			continue
		var effect_targets := _resolve_effect_targets(target_descriptor)
		for effect_target in effect_targets:
			if _apply_effect_to_target(effect, effect_target):
				affected_targets.append(effect_target)

	_update_battle_result_if_finished()
	return {
		"success": true,
		"affected_targets": affected_targets,
		"battle_finished": is_battle_over(),
		"battle_result": battle_result,
	}


func is_valid_room() -> bool:
	return super.is_valid_room() and room_type == RoomEnums.RoomType.BATTLE


func _resolve_effect_targets(target_descriptor: Dictionary) -> Array[Dictionary]:
	var target_kind := StringName(target_descriptor.get("kind", &""))
	var resolved_targets: Array[Dictionary] = []
	if target_kind == &"all_monsters":
		for monster_index in get_living_monster_indexes():
			resolved_targets.append({
				"kind": &"monster",
				"index": monster_index,
			})
		return resolved_targets
	if target_kind == &"monster":
		var monster_index := int(target_descriptor.get("index", -1))
		if can_target_monster(monster_index):
			resolved_targets.append(target_descriptor)
		return resolved_targets
	if target_kind == &"player" and can_target_player():
		resolved_targets.append(target_descriptor)
	return resolved_targets


func _apply_effect_to_target(effect: AbilityEffectDefinition, target_descriptor: Dictionary) -> bool:
	var target_kind := StringName(target_descriptor.get("kind", &""))
	match effect.effect_type:
		&"damage":
			if target_kind == &"monster":
				var monster_index := int(target_descriptor.get("index", -1))
				if not can_target_monster(monster_index):
					return false
				monster_views[monster_index].take_damage(effect.magnitude)
				return true
			if target_kind == &"player":
				if player_instance != null:
					player_instance.take_damage(effect.magnitude)
				if player_view != null:
					player_view.take_damage(effect.magnitude)
				return true
		&"healing":
			if target_kind == &"player":
				if player_instance != null:
					player_instance.heal(effect.magnitude)
				if player_view != null:
					player_view.heal(effect.magnitude)
				return true
			if target_kind == &"monster":
				var monster_index := int(target_descriptor.get("index", -1))
				if not can_target_monster(monster_index):
					return false
				monster_views[monster_index].heal(effect.magnitude)
				return true
	return false


func _reset_battle_progression() -> void:
	battle_status = &"not_started"
	battle_result = &"none"
	current_turn_owner = &"none"
	current_monster_turn_index = -1
	turn_counter = 0


func _update_battle_result_if_finished() -> bool:
	if player_view == null or not player_view.is_alive():
		battle_status = &"defeat"
		battle_result = &"player_dead"
		current_turn_owner = &"none"
		current_monster_turn_index = -1
		return true
	if get_living_monster_indexes().is_empty():
		battle_status = &"victory"
		battle_result = &"monsters_defeated"
		current_turn_owner = &"none"
		current_monster_turn_index = -1
		return true
	return false


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
