extends Room
class_name BattleRoom

const DEFAULT_FLOOR_TEXTURE := preload("res://assets/material/дерево.png")
const DUNGEON_FLOOR_TEXTURE_1 := preload("res://assets/material/dangeon_floor_1.png")
const DUNGEON_FLOOR_TEXTURE_2 := preload("res://assets/material/dangeon_floor_2.png")
const TEST_PLAYER_TEXTURE := preload("res://assets/entity/monsters/test_player.png")
const TEST_MONSTER_DEFINITION := preload("res://content/monsters/definitions/test_monster.tres")
const RAT_MONSTER_DEFINITION := preload("res://content/monsters/definitions/rat.tres")
const GOBLIN_MONSTER_DEFINITION := preload("res://content/monsters/definitions/goblin.tres")
const GOBLIN_SHAMAN_MONSTER_DEFINITION := preload("res://content/monsters/definitions/goblin_shaman.tres")
const TURTLE_MONSTER_DEFINITION := preload("res://content/monsters/definitions/turtle.tres")
const HOBGOBLIN_MONSTER_DEFINITION := preload("res://content/monsters/definitions/hobgoblin.tres")
const CRUSHING_SHOT_UPGRADE_1_2_ABILITY := preload("res://content/abilities/definitions/crushing_shot_upgrade_1_2.tres")
const PROTECTION_SPELL_UPGRADE_1_2_ABILITY := preload("res://content/abilities/definitions/protection_spell_upgrade_1_2.tres")
const REROLL_UPGRADE_2_2_ABILITY := preload("res://content/abilities/definitions/reroll_upgrade_2_2.tres")
const REROLL_ALL_UPGRADE_2_2_ABILITY := preload("res://content/abilities/definitions/reroll_all_upgrade_2_2.tres")
const POISON_INJECTION_ABILITY := preload("res://content/abilities/definitions/poison_injection.tres")
const PEREVERTYSH_DICE := preload("res://content/dice/definitions/perevertysh.tres")
const KAMIKAZE_DICE := preload("res://content/dice/definitions/kamikaze.tres")
const DUPLICATE_DICE := preload("res://content/dice/definitions/duplicate.tres")
const JOKER_DICE := preload("res://content/dice/definitions/joker.tres")
const PRILIPALA_DICE := preload("res://content/dice/definitions/prilipala.tres")
const GOLDEN_DICE := preload("res://content/dice/definitions/golden.tres")
const POISONED_DICE := preload("res://content/dice/definitions/poisoned.tres")
const GlobalMapDiceEvolutionService = preload("res://content/global_map/dice/global_map_dice_evolution_service.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const BattleTurnRuntime = preload("res://content/combat/runtime/battle_turn_runtime.gd")
const BattleEffectRuntime = preload("res://content/combat/runtime/battle_effect_runtime.gd")
const BattleCombatRuntimeState = preload("res://content/combat/runtime/battle_combat_runtime_state.gd")
const ArtifactRuntime = preload("res://content/artifacts/runtime/artifact_runtime.gd")

const PLAYER_SPRITE_POSITION := Vector3(-3.0, 0.01, -2.5)
const PLAYER_SPRITE_SCALE := Vector3(2.0, 2.0, 2.0)
const MONSTER_SPRITE_POSITION := Vector3(3.0, 0.01, -2.5)
const MONSTER_SPRITE_SCALE := Vector3(2.0, 2.0, 2.0)
const PLAYER_ABILITY_FRAME_POSITION := Vector3(-7.5, 0.01, 0.0)
const MONSTER_ABILITY_FRAME_POSITION := Vector3(7.4, 0.01, 0.0)
const STACK_SPACING_Z := 2.8
const DICE_PLACE_Z_POSITIONS := [-0.557, -0.007, 0.55]

const NORMAL_RUNTIME_MONSTER_POOL: Array[MonsterDefinition] = [
	RAT_MONSTER_DEFINITION,
	GOBLIN_MONSTER_DEFINITION,
	TURTLE_MONSTER_DEFINITION,
	HOBGOBLIN_MONSTER_DEFINITION,
]
const ELITE_RUNTIME_MONSTER_POOL: Array[MonsterDefinition] = [
	GOBLIN_SHAMAN_MONSTER_DEFINITION,
]


class CombatantViewData:
	extends RefCounted

	var sprite: Texture2D
	var abilities: Array[AbilityDefinition] = []
	var base_scale: Vector3 = Vector3.ONE
	var current_hp := 0
	var max_hp := 0
	var dice_count := 0
	var dice_loadout: Array[DiceDefinition] = []
	var size_multiplier := 1.0
	var ai_profile: MonsterAiProfile
	var combatant_id: StringName = &""
	var side: StringName = &""

	func _init(
		next_sprite: Texture2D = null,
		next_abilities: Array[AbilityDefinition] = [],
		next_scale: Vector3 = Vector3.ONE,
		next_current_hp: int = 0,
		next_max_hp: int = 0,
		next_dice_count: int = 0,
		next_dice_loadout: Array[DiceDefinition] = [],
		next_size_multiplier: float = 1.0,
		next_ai_profile: MonsterAiProfile = null,
		next_combatant_id: StringName = &"",
		next_side: StringName = &""
	) -> void:
		sprite = next_sprite
		abilities = _sanitize_abilities(next_abilities)
		base_scale = next_scale
		current_hp = maxi(next_current_hp, 0)
		max_hp = maxi(next_max_hp, 0)
		dice_count = maxi(next_dice_count, 0)
		dice_loadout = _sanitize_dice_loadout(next_dice_loadout)
		size_multiplier = clampf(next_size_multiplier, 0.2, 2.0)
		ai_profile = next_ai_profile
		combatant_id = next_combatant_id
		side = next_side

	static func _sanitize_abilities(next_abilities: Array[AbilityDefinition]) -> Array[AbilityDefinition]:
		var sanitized: Array[AbilityDefinition] = []
		for ability in next_abilities:
			if ability != null:
				sanitized.append(ability)
		return sanitized

	static func _sanitize_dice_loadout(next_dice_loadout: Array[DiceDefinition]) -> Array[DiceDefinition]:
		var sanitized: Array[DiceDefinition] = []
		for dice_definition in next_dice_loadout:
			if dice_definition != null:
				sanitized.append(dice_definition)
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
var combat_runtime_state: BattleCombatRuntimeState = BattleCombatRuntimeState.new()
var left_floor_texture: Texture2D = DEFAULT_FLOOR_TEXTURE
var right_floor_texture: Texture2D = DEFAULT_FLOOR_TEXTURE
var current_turn_owner: StringName = &"none"
var current_monster_turn_index := -1
var turn_counter := 0
var turn_start_pending := false
var battle_result: StringName = &"none"
var _ability_cooldowns_by_owner: Dictionary = {}
var _used_once_per_battle_abilities_by_owner: Dictionary = {}
var _ability_uses_by_owner: Dictionary = {}
var _ability_uses_this_turn_by_owner: Dictionary = {}
var _last_debug_combat_message := ""
var _last_debug_combat_message_repeat_count := 0


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
	if player_instance != null:
		player_instance.ensure_runtime_initialized_from_base_stat()
	var abilities: Array[AbilityDefinition] = []
	var current_hp := 0
	var max_hp := 0
	var dice_count := 0
	var dice_loadout: Array[DiceDefinition] = []
	var ai_profile: MonsterAiProfile
	if player_instance != null:
		abilities.assign(player_instance.ability_loadout)
		current_hp = player_instance.current_hp
		dice_count = player_instance.dice_loadout.size()
		if player_instance.base_stat != null:
			max_hp = player_instance.get_max_hp()
	player_view = CombatantViewData.new(
		sprite,
		abilities,
		PLAYER_SPRITE_SCALE,
		current_hp,
		max_hp,
		dice_count,
		dice_loadout,
		1.0,
		ai_profile,
		&"player",
		&"player"
	)
	combat_runtime_state.set_player_state(player_view.combatant_id, player_view.side)
	if player_view.is_alive():
		combat_runtime_state.mark_combatant_alive({"side": &"player"})
	else:
		combat_runtime_state.mark_combatant_dead({"side": &"player"})
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
				MONSTER_SPRITE_SCALE * clampf(monster_definition.size_multiplier, 0.2, 2.0),
				monster_definition.max_health,
				monster_definition.max_health,
				monster_definition.get_combat_dice_count(),
				monster_definition.get_combat_dice_loadout(),
				clampf(monster_definition.size_multiplier, 0.2, 2.0),
				monster_definition.ai_profile,
				StringName("%s_%d" % [monster_definition.monster_id, monster_views.size()]),
				&"enemy"
			)
		)
	var runtime_monster_descriptors: Array[Dictionary] = []
	for monster_view in monster_views:
		if monster_view == null:
			continue
		runtime_monster_descriptors.append({
			"combatant_id": monster_view.combatant_id,
			"side": monster_view.side,
		})
	combat_runtime_state.set_monster_states(runtime_monster_descriptors)
	for monster_index in monster_views.size():
		if can_target_monster(monster_index):
			combat_runtime_state.mark_combatant_alive({"side": &"enemy", "index": monster_index})
		else:
			combat_runtime_state.mark_combatant_dead({"side": &"enemy", "index": monster_index})
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
	if index < 0 or index >= monster_views.size() or monster_views[index] == null:
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
	var entry_by_ability_key := {}
	for monster_index in monster_views.size():
		var monster_view := monster_views[monster_index]
		if monster_view == null:
			continue
		for ability_index in monster_view.abilities.size():
			var ability := monster_view.abilities[ability_index]
			if ability == null:
				continue
			var ability_key := _build_monster_ability_key(ability)
			if entry_by_ability_key.has(ability_key):
				var existing_index := int(entry_by_ability_key[ability_key])
				if existing_index >= 0 and existing_index < resolved.size():
					var existing_entry := resolved[existing_index]
					var shared_monsters := existing_entry.get("monster_indexes", PackedInt32Array()) as PackedInt32Array
					if not shared_monsters.has(monster_index):
						shared_monsters.append(monster_index)
					existing_entry["monster_indexes"] = shared_monsters
					var ability_indexes := existing_entry.get("ability_indexes_by_monster", {}) as Dictionary
					ability_indexes[monster_index] = ability_index
					existing_entry["ability_indexes_by_monster"] = ability_indexes
					resolved[existing_index] = existing_entry
				continue
			var entry := {
				"monster_index": monster_index,
				"ability_index": ability_index,
				"ability": ability,
				"monster_indexes": PackedInt32Array([monster_index]),
				"ability_indexes_by_monster": {monster_index: ability_index},
			}
			resolved.append(entry)
			entry_by_ability_key[ability_key] = resolved.size() - 1
	return resolved


func _build_monster_ability_key(ability: AbilityDefinition) -> StringName:
	if ability == null:
		return &""
	if not ability.resource_path.is_empty():
		return StringName(ability.resource_path)
	return StringName("%s|%s" % [ability.ability_id, ability.display_name])


func get_required_dice_slots(ability: AbilityDefinition) -> int:
	return mini(BattleAbilityRuntime.build_slot_conditions(ability).size(), 3)


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


func get_status_container_for_descriptor(descriptor: Dictionary):
	if combat_runtime_state == null:
		return null
	return combat_runtime_state.get_status_container_for_descriptor(descriptor)


func get_status_container_for_turn_owner():
	if combat_runtime_state == null:
		return null
	return combat_runtime_state.get_status_container_for_turn_owner(current_turn_owner, current_monster_turn_index)


func clear_all_statuses() -> void:
	if combat_runtime_state == null:
		return
	combat_runtime_state.clear_all_statuses()


func publish_status_event(event_name: StringName, payload: Dictionary = {}) -> void:
	if combat_runtime_state == null:
		return
	combat_runtime_state.publish_status_event(event_name, payload)


func get_status_event_log() -> Array[Dictionary]:
	if combat_runtime_state == null:
		return []
	return combat_runtime_state.get_status_event_log()


func clear_status_event_log() -> void:
	if combat_runtime_state == null:
		return
	combat_runtime_state.clear_status_event_log()


func add_turn_start_dice_penalty(descriptor: Dictionary, penalty: int) -> int:
	if combat_runtime_state == null:
		return 0
	return combat_runtime_state.add_turn_start_dice_penalty(descriptor, penalty)


func consume_turn_start_dice_penalty(descriptor: Dictionary) -> int:
	if combat_runtime_state == null:
		return 0
	return combat_runtime_state.consume_turn_start_dice_penalty(descriptor)


func apply_damage_to_descriptor(descriptor: Dictionary, amount: int) -> bool:
	var resolved_damage := maxi(amount, 0)
	var side := StringName(descriptor.get("side", &""))
	if side == &"player":
		if not can_target_player():
			return false
		if resolved_damage <= 0:
			return true
		if player_instance != null:
			player_instance.take_damage(resolved_damage)
		player_view.take_damage(resolved_damage)
		var current_hp := player_view.current_hp
		_debug_combat_log("Урон %s -%d (%d/%d)." % [
			_format_descriptor_label(descriptor),
			resolved_damage,
			current_hp,
			player_view.max_hp,
		])
		if player_instance != null:
			ArtifactRuntime.trigger_event(
				ArtifactRuntime.EVENT_DAMAGE_TAKEN,
				self,
				{"side": &"player"},
				player_instance.get_active_artifact_definitions(),
				{
					"turn_owner": current_turn_owner,
					"damage": resolved_damage,
				}
			)
		if not player_view.is_alive():
			_on_combatant_died({"side": &"player"})
		return true
	if side == &"enemy":
		var monster_index := int(descriptor.get("index", -1))
		if not can_target_monster(monster_index):
			return false
		if resolved_damage <= 0:
			return true
		var monster_view := monster_views[monster_index]
		monster_view.take_damage(resolved_damage)
		var current_hp := monster_view.current_hp
		_debug_combat_log("Урон %s -%d (%d/%d)." % [
			_format_descriptor_label(descriptor),
			resolved_damage,
			current_hp,
			monster_view.max_hp,
		])
		if not monster_views[monster_index].is_alive():
			_on_combatant_died({"side": &"enemy", "index": monster_index})
		return true
	return false


func apply_heal_to_descriptor(descriptor: Dictionary, amount: int) -> bool:
	var resolved_heal := maxi(amount, 0)
	if resolved_heal <= 0:
		return false
	var side := StringName(descriptor.get("side", &""))
	if side == &"player":
		if not can_target_player():
			return false
		if player_instance != null:
			player_instance.heal(resolved_heal)
		var applied_heal := player_view.heal(resolved_heal)
		_debug_combat_log("ХП %s +%d (%d/%d)." % [
			_format_descriptor_label(descriptor),
			applied_heal,
			player_view.current_hp,
			player_view.max_hp,
		])
		return true
	if side == &"enemy":
		var monster_index := int(descriptor.get("index", -1))
		if not can_target_monster(monster_index):
			return false
		var monster_view := monster_views[monster_index]
		var applied_heal := monster_view.heal(resolved_heal)
		_debug_combat_log("ХП %s +%d (%d/%d)." % [
			_format_descriptor_label(descriptor),
			applied_heal,
			monster_view.current_hp,
			monster_view.max_hp,
		])
		return true
	return false


func _on_combatant_died(descriptor: Dictionary) -> void:
	if combat_runtime_state == null:
		return
	combat_runtime_state.mark_combatant_dead(descriptor)
	if StringName(descriptor.get("side", &"")) == &"enemy":
		_purge_dead_monsters()
	BattleTurnRuntime.update_battle_result_if_finished(self)


func _purge_dead_monsters() -> void:
	for monster_index in monster_views.size():
		var monster_view := monster_views[monster_index]
		if monster_view == null:
			continue
		if monster_view.is_alive():
			continue
		monster_views[monster_index] = null

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


func process_turn_start_if_pending() -> bool:
	return BattleTurnRuntime.process_turn_start_if_pending(self)


func on_turn_started() -> void:
	var owner_descriptor := _resolve_turn_owner_descriptor()
	if owner_descriptor.is_empty():
		return
	_decrement_ability_cooldowns_for_owner(owner_descriptor)
	_reset_ability_use_counters_for_owner_turn(owner_descriptor)


func can_activate_current_turn_ability(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	var owner_descriptor := _resolve_turn_owner_descriptor()
	if owner_descriptor.is_empty():
		return false
	if ability.once_per_battle and _is_ability_used_once_per_battle(owner_descriptor, ability):
		_debug_combat_log("Способность %s заблокирована: once_per_battle уже использована." % String(ability.ability_id))
		return false
	if not _is_within_custom_ability_use_limits(owner_descriptor, ability):
		return false
	var cooldown_turns := _get_ability_cooldown_turns(owner_descriptor, ability)
	if cooldown_turns > 0:
		_debug_combat_log("Способность %s заблокирована: осталось %d ход(а) кулдауна." % [String(ability.ability_id), cooldown_turns])
		return false
	return true


func register_current_turn_ability_use(ability: AbilityDefinition) -> void:
	if ability == null:
		return
	var owner_descriptor := _resolve_turn_owner_descriptor()
	if owner_descriptor.is_empty():
		return
	if ability.once_per_battle:
		_mark_ability_used_once_per_battle(owner_descriptor, ability)
	_register_ability_use_in_counters(owner_descriptor, ability)
	var cooldown_turns := maxi(ability.cooldown_turns, 0)
	if cooldown_turns <= 0:
		return
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	var owner_cooldowns: Dictionary = _ability_cooldowns_by_owner.get(owner_key, {})
	owner_cooldowns[ability.ability_id] = cooldown_turns
	_ability_cooldowns_by_owner[owner_key] = owner_cooldowns
	_debug_combat_log("Кулдаун способности %s установлен на %d ход(а)." % [ability.ability_id, cooldown_turns])


func activate_player_ability(ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	return activate_current_turn_ability(ability, target_descriptor)


func activate_current_turn_ability(ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	return BattleEffectRuntime.activate_current_turn_ability(self, ability, target_descriptor)


func is_valid_room() -> bool:
	return super.is_valid_room() and room_type == RoomEnums.RoomType.BATTLE


func _reset_battle_progression() -> void:
	BattleTurnRuntime.reset_battle_progression(self)
	_ability_cooldowns_by_owner.clear()
	_used_once_per_battle_abilities_by_owner.clear()
	_ability_uses_by_owner.clear()
	_ability_uses_this_turn_by_owner.clear()
	_last_debug_combat_message = ""
	_last_debug_combat_message_repeat_count = 0


func _format_descriptor_label(descriptor: Dictionary) -> String:
	var side := StringName(descriptor.get("side", &""))
	if side == &"player":
		return "игрок"
	if side == &"enemy":
		return "монстр #%d" % (int(descriptor.get("index", -1)) + 1)
	return "неизвестно"


func _debug_combat_log(message: String) -> void:
	if not OS.is_debug_build():
		return
	if message == _last_debug_combat_message:
		_last_debug_combat_message_repeat_count += 1
		return
	if _last_debug_combat_message_repeat_count > 0:
		print("[Debug][BattleRoom] Предыдущее сообщение повторилось еще %d раз." % _last_debug_combat_message_repeat_count)
	_last_debug_combat_message = message
	_last_debug_combat_message_repeat_count = 0
	print("[Debug][BattleRoom] %s" % message)


func _resolve_turn_owner_descriptor() -> Dictionary:
	if current_turn_owner == &"player" and can_target_player():
		return {"side": &"player"}
	if current_turn_owner == &"monster" and can_target_monster(current_monster_turn_index):
		return {
			"side": &"enemy",
			"index": current_monster_turn_index,
		}
	return {}


func _decrement_ability_cooldowns_for_owner(owner_descriptor: Dictionary) -> void:
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	var owner_cooldowns: Dictionary = _ability_cooldowns_by_owner.get(owner_key, {})
	if owner_cooldowns.is_empty():
		return
	var next_cooldowns: Dictionary = {}
	for ability_id in owner_cooldowns.keys():
		var remaining_turns := maxi(int(owner_cooldowns.get(ability_id, 0)) - 1, 0)
		if remaining_turns > 0:
			next_cooldowns[ability_id] = remaining_turns
	if next_cooldowns.is_empty():
		_ability_cooldowns_by_owner.erase(owner_key)
	else:
		_ability_cooldowns_by_owner[owner_key] = next_cooldowns


func _get_ability_cooldown_turns(owner_descriptor: Dictionary, ability: AbilityDefinition) -> int:
	if ability == null:
		return 0
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	var owner_cooldowns: Dictionary = _ability_cooldowns_by_owner.get(owner_key, {})
	return maxi(int(owner_cooldowns.get(ability.ability_id, 0)), 0)


func _build_owner_cooldown_key(owner_descriptor: Dictionary) -> StringName:
	var side := String(owner_descriptor.get("side", ""))
	var index := int(owner_descriptor.get("index", -1))
	return StringName("%s:%d" % [side, index])




func _is_within_custom_ability_use_limits(owner_descriptor: Dictionary, ability: AbilityDefinition) -> bool:
	if ability == null:
		return true
	var max_uses_per_battle := maxi(ability.max_uses_per_battle, 0)
	if max_uses_per_battle > 0:
		var used_in_battle := _get_ability_use_count_for_owner(owner_descriptor, ability)
		if used_in_battle >= max_uses_per_battle:
			_debug_combat_log("Способность %s заблокирована: достигнут лимит %d использований за бой." % [String(ability.ability_id), max_uses_per_battle])
			return false
	var max_uses_per_turn := maxi(ability.max_uses_per_turn, 0)
	if max_uses_per_turn > 0:
		var used_this_turn := _get_ability_use_count_for_owner_this_turn(owner_descriptor, ability)
		if used_this_turn >= max_uses_per_turn:
			_debug_combat_log("Способность %s заблокирована: достигнут лимит %d использований за ход." % [String(ability.ability_id), max_uses_per_turn])
			return false
	return true


func _register_ability_use_in_counters(owner_descriptor: Dictionary, ability: AbilityDefinition) -> void:
	if ability == null:
		return
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	var ability_key := String(ability.ability_id)
	if ability_key.is_empty():
		return
	var used_in_battle := _get_ability_use_count_for_owner(owner_descriptor, ability) + 1
	var owner_battle_uses: Dictionary = _ability_uses_by_owner.get(owner_key, {})
	owner_battle_uses[ability_key] = used_in_battle
	_ability_uses_by_owner[owner_key] = owner_battle_uses
	var used_this_turn := _get_ability_use_count_for_owner_this_turn(owner_descriptor, ability) + 1
	var owner_turn_uses: Dictionary = _ability_uses_this_turn_by_owner.get(owner_key, {})
	owner_turn_uses[ability_key] = used_this_turn
	_ability_uses_this_turn_by_owner[owner_key] = owner_turn_uses
	_debug_combat_log("Счетчики способности %s: за бой=%d, за ход=%d." % [ability_key, used_in_battle, used_this_turn])


func _get_ability_use_count_for_owner(owner_descriptor: Dictionary, ability: AbilityDefinition) -> int:
	if ability == null:
		return 0
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	var owner_uses: Dictionary = _ability_uses_by_owner.get(owner_key, {})
	return maxi(int(owner_uses.get(String(ability.ability_id), 0)), 0)


func _get_ability_use_count_for_owner_this_turn(owner_descriptor: Dictionary, ability: AbilityDefinition) -> int:
	if ability == null:
		return 0
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	var owner_uses: Dictionary = _ability_uses_this_turn_by_owner.get(owner_key, {})
	return maxi(int(owner_uses.get(String(ability.ability_id), 0)), 0)


func _reset_ability_use_counters_for_owner_turn(owner_descriptor: Dictionary) -> void:
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	if not _ability_uses_this_turn_by_owner.has(owner_key):
		return
	_ability_uses_this_turn_by_owner.erase(owner_key)
	_debug_combat_log("Сброшены счетчики использований за ход для %s." % String(owner_key))

func _mark_ability_used_once_per_battle(owner_descriptor: Dictionary, ability: AbilityDefinition) -> void:
	if ability == null:
		return
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	var used_abilities: Dictionary = _used_once_per_battle_abilities_by_owner.get(owner_key, {})
	used_abilities[ability.ability_id] = true
	_used_once_per_battle_abilities_by_owner[owner_key] = used_abilities
	_debug_combat_log("One-shot способность %s помечена как использованная." % String(ability.ability_id))


func _is_ability_used_once_per_battle(owner_descriptor: Dictionary, ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	var owner_key := _build_owner_cooldown_key(owner_descriptor)
	var used_abilities: Dictionary = _used_once_per_battle_abilities_by_owner.get(owner_key, {})
	return bool(used_abilities.get(ability.ability_id, false))


static func create_test_battle_room() -> BattleRoom:
	var room := BattleRoom.new()
	room.room_id = "test_battle_room"
	room.set_floor_textures(DEFAULT_FLOOR_TEXTURE, DEFAULT_FLOOR_TEXTURE)
	room.set_player_data(build_default_player(), TEST_PLAYER_TEXTURE)
	room.set_monsters_from_definitions([TEST_MONSTER_DEFINITION])
	return room


static func create_runtime_battle_room(player: Player, marker_type: String = "", rng: RandomNumberGenerator = null) -> BattleRoom:
	var room := BattleRoom.new()
	room.room_id = "runtime_battle_room"
	var runtime_player := player
	if runtime_player == null:
		runtime_player = build_default_player()
	else:
		runtime_player.ensure_runtime_initialized_from_base_stat()
	var resolved_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		resolved_rng.randomize()
	var runtime_setup := _build_runtime_encounter_setup(marker_type, resolved_rng)
	var floor_texture: Texture2D = runtime_setup.get("floor_texture", DEFAULT_FLOOR_TEXTURE)
	room.set_floor_textures(floor_texture, floor_texture)
	room.set_player_data(runtime_player, TEST_PLAYER_TEXTURE)
	var raw_monsters = runtime_setup.get("monsters", [])
	var monster_definitions := _collect_valid_monster_definitions(raw_monsters)
	if monster_definitions.is_empty():
		print("[Debug][BattleRoom] Runtime encounter has no valid monsters. Fallback to test monster.")
		monster_definitions.append(TEST_MONSTER_DEFINITION)
	print("[Debug][BattleRoom] Runtime encounter marker=%s monsters=%s." % [marker_type, _build_monster_spawn_debug_list(monster_definitions)])
	room.set_monsters_from_definitions(monster_definitions)
	return room


static func _build_runtime_encounter_setup(marker_type: String, rng: RandomNumberGenerator) -> Dictionary:
	var normalized_marker_type := marker_type.strip_edges().to_lower()
	if normalized_marker_type == GlobalMapDiceEvolutionService.ELITE_FACE_TAG:
		var elite_monster := _pick_random_runtime_monster_definition(rng, ELITE_RUNTIME_MONSTER_POOL, GOBLIN_SHAMAN_MONSTER_DEFINITION)
		print("[Debug][BattleRoom] Elite encounter selected monster=%s." % _resolve_monster_debug_label(elite_monster))
		return {
			"floor_texture": _pick_runtime_floor_texture(rng, [DEFAULT_FLOOR_TEXTURE, DUNGEON_FLOOR_TEXTURE_1, DUNGEON_FLOOR_TEXTURE_2]),
			"monsters": [elite_monster],
		}
	var normal_monster := _pick_random_runtime_monster_definition(rng, NORMAL_RUNTIME_MONSTER_POOL, RAT_MONSTER_DEFINITION)
	var normal_monsters: Array[MonsterDefinition] = [normal_monster]
	if normal_monster == RAT_MONSTER_DEFINITION:
		normal_monsters.append(RAT_MONSTER_DEFINITION)
	print("[Debug][BattleRoom] Normal encounter selected monster=%s count=%d." % [_resolve_monster_debug_label(normal_monster), normal_monsters.size()])
	return {
		"floor_texture": _pick_runtime_floor_texture(rng, [DUNGEON_FLOOR_TEXTURE_1, DUNGEON_FLOOR_TEXTURE_2]),
		"monsters": normal_monsters,
	}


static func _pick_random_runtime_monster_definition(rng: RandomNumberGenerator, monster_pool: Array[MonsterDefinition], fallback_monster: MonsterDefinition) -> MonsterDefinition:
	var valid_pool := _collect_valid_monster_definitions(monster_pool)
	if valid_pool.is_empty():
		print("[Debug][BattleRoom] Runtime monster pool is empty. Fallback=%s." % _resolve_monster_debug_label(fallback_monster))
		return fallback_monster
	var selected_index := rng.randi_range(0, valid_pool.size() - 1)
	var selected_monster := valid_pool[selected_index]
	print("[Debug][BattleRoom] Runtime monster pool size=%d selected_index=%d selected_monster=%s." % [valid_pool.size(), selected_index, _resolve_monster_debug_label(selected_monster)])
	return selected_monster


static func _resolve_monster_debug_label(monster_definition: MonsterDefinition) -> String:
	if monster_definition == null:
		return "null"
	if not monster_definition.monster_id.is_empty():
		return monster_definition.monster_id
	return "unknown_monster"


static func _collect_valid_monster_definitions(raw_monsters) -> Array[MonsterDefinition]:
	var monster_definitions: Array[MonsterDefinition] = []
	if not (raw_monsters is Array):
		return monster_definitions
	for raw_monster in raw_monsters:
		if raw_monster is MonsterDefinition:
			monster_definitions.append(raw_monster as MonsterDefinition)
	return monster_definitions


static func _build_monster_spawn_debug_list(monsters: Array[MonsterDefinition]) -> String:
	if monsters.is_empty():
		return "[]"
	var labels: Array[String] = []
	for monster_definition in monsters:
		if monster_definition == null:
			labels.append("null")
			continue
		labels.append(monster_definition.monster_id)
	return "[" + ", ".join(labels) + "]"


static func _pick_runtime_floor_texture(rng: RandomNumberGenerator, floor_pool: Array[Texture2D]) -> Texture2D:
	if floor_pool.is_empty():
		return DEFAULT_FLOOR_TEXTURE
	return floor_pool[rng.randi_range(0, floor_pool.size() - 1)]


static func build_default_player() -> Player:
	var base_stat := PlayerBaseStat.new()
	base_stat.player_id = "test_player"
	base_stat.display_name = "Тестовый игрок"
	base_stat.max_hp = 30
	base_stat.starting_hp = 30
	base_stat.starting_armor = 0
	base_stat.starting_abilities = [
		CRUSHING_SHOT_UPGRADE_1_2_ABILITY,
		PROTECTION_SPELL_UPGRADE_1_2_ABILITY,
		REROLL_UPGRADE_2_2_ABILITY,
		REROLL_ALL_UPGRADE_2_2_ABILITY,
		POISON_INJECTION_ABILITY,
	]
	print("[Debug][BattleRoom] Default player starts with predefined upgraded abilities, including Сокрушающий выстрел++, Заклинание защиты++ (1.2 branch), and base poison archetype card (Отравляющий укол).")
	var starter_ability_ids: Array[String] = []
	for ability in base_stat.starting_abilities:
		if ability == null:
			starter_ability_ids.append("null")
			continue
		starter_ability_ids.append("%s(lvl=%d)" % [ability.ability_id, ability.upgrade_level])
	print("[Debug][BattleRoom] Default player starting abilities: %s." % ", ".join(starter_ability_ids))
	base_stat.starting_dice = [
		preload("res://content/resources/base_cube.tres"),
		preload("res://content/resources/base_cube.tres"),
		preload("res://content/resources/base_cube.tres"),
		PEREVERTYSH_DICE,
		KAMIKAZE_DICE,
		PRILIPALA_DICE,
		GOLDEN_DICE,
		POISONED_DICE,
		DUPLICATE_DICE,
		JOKER_DICE,
	]
	return Player.new(base_stat)
