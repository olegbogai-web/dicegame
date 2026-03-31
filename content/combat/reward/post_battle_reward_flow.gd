extends RefCounted
class_name PostBattleRewardFlow

const Dice = preload("res://content/dice/dice.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")

const POST_BATTLE_REWARD_DICE_SIZE_MULTIPLIER := Vector3(4.0, 4.0, 4.0)
const POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER := 0.75
const POST_BATTLE_REWARD_DICE_DELAY_SECONDS := 1.0
const REWARD_CARD_NEW_FACE_ID := &"card_+"
const REWARD_CARD_UP_FACE_ID := &"card_up"
const REWARD_ARTIFACT_FACE_ID := &"artifact_+"
const REWARD_CUBE_FACE_ID := &"cube_+"
const ABILITY_REWARD_OPTIONS_COUNT := 3
const ARTIFACT_REWARD_OPTIONS_COUNT := 2
const CUBE_REWARD_OPTIONS_COUNT := 2
const ABILITY_REWARD_CARD_MIN_SPACING_X := 3.2
const ABILITY_REWARD_CARD_GAP_X := 0.35
const ARTIFACT_REWARD_MIN_SPACING_X := 1.75
const ARTIFACT_REWARD_GAP_X := 0.25
const ABILITY_DEFINITIONS_DIRECTORY := "res://content/abilities/definitions"
const ARTIFACT_DEFINITIONS_DIRECTORY := "res://content/artifacts/definitions"
const DICE_DEFINITIONS_DIRECTORY := "res://content/dice/definitions"
const RARITY_COMMON_WEIGHT := 50.0
const RARITY_UNCOMMON_WEIGHT := 30.0
const RARITY_RARE_WEIGHT := 20.0
const RARITY_UNIQUE_WEIGHT := 10.0
const ARTIFACT_RARITY_COMMON_WEIGHT := 50.0
const ARTIFACT_RARITY_UNCOMMON_WEIGHT := 25.0
const ARTIFACT_RARITY_RARE_WEIGHT := 15.0
const ARTIFACT_RARITY_UNIQUE_WEIGHT := 10.0
const CUBE_RARITY_COMMON_WEIGHT := 50.0
const CUBE_RARITY_UNCOMMON_WEIGHT := 25.0
const CUBE_RARITY_RARE_WEIGHT := 15.0
const CUBE_RARITY_UNIQUE_WEIGHT := 10.0
const GLOBAL_MAP_SCENE_PATH := "res://scenes/global_map_room.tscn"
const CUBE_REWARD_PREVIEW_ROTATION_DEGREES := Vector3(45.0, 10.0, -120.0)
const CUBE_REWARD_PREVIEW_SCALE := Vector3(3.0, 3.0, 3.0)
const CUBE_REWARD_PREVIEW_Y_OFFSET := 0.75


func _handle_post_battle_reward_dice(owner: Node) -> void:
	if owner._has_spawned_post_battle_reward_dice or owner._is_waiting_post_battle_reward_dice:
		return
	owner._is_waiting_post_battle_reward_dice = true
	await owner.get_tree().create_timer(POST_BATTLE_REWARD_DICE_DELAY_SECONDS).timeout
	owner._is_waiting_post_battle_reward_dice = false
	if owner._board == null or owner.battle_room_data == null:
		return
	if owner.battle_room_data.battle_status != &"victory":
		return
	print("[Debug][RewardFlow] Бой выигран. Запуск post-battle броска кубов награды.")
	var player = owner.battle_room_data.player_instance
	if player == null:
		return
	var reward_cubes: Array[DiceDefinition] = player.get_active_reward_cubes()
	var money_cube = player.runtime_money_cube
	if reward_cubes.is_empty() and money_cube == null:
		return
	var requests: Array[DiceThrowRequest] = []
	for reward_cube in reward_cubes:
		if reward_cube == null:
			continue
		requests.append(owner._build_dice_throw_request(reward_cube, {"owner": &"reward"}))
	if money_cube != null:
		requests.append(owner._build_dice_throw_request(money_cube, {"owner": &"reward"}))
	if requests.is_empty():
		return
	for request in requests:
		request.extra_size_multiplier = POST_BATTLE_REWARD_DICE_SIZE_MULTIPLIER
	var spawned_dice = owner._board.throw_dice(requests)
	print("[Debug][RewardFlow] Куб награды/денег брошен. Количество кубов: %d." % spawned_dice.size())
	for dice_body in spawned_dice:
		if dice_body == null:
			continue
		dice_body.linear_velocity.y *= POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER
	owner._has_spawned_post_battle_reward_dice = true
	owner._has_processed_post_battle_reward_result = false


func _try_resolve_post_battle_reward_dice_result(owner: Node) -> void:
	if not owner._has_spawned_post_battle_reward_dice or owner._has_processed_post_battle_reward_result:
		return
	var reward_dice := _find_post_battle_reward_die(owner)
	if reward_dice == null:
		return
	var all_reward_dice = owner._get_turn_dice(&"reward")
	for dice in all_reward_dice:
		if dice == null or not dice.has_completed_first_stop():
			return
	owner._has_processed_post_battle_reward_result = true
	var reward_face := ""
	var reward_top_face := reward_dice.get_top_face()
	if reward_top_face != null:
		reward_face = reward_top_face.text_value
	print("[Debug][RewardFlow] На кубе награды выпало: %s." % reward_face)
	if StringName(reward_face) == REWARD_CARD_NEW_FACE_ID:
		_show_ability_reward_options(owner)
	elif StringName(reward_face) == REWARD_CARD_UP_FACE_ID:
		_show_ability_upgrade_options(owner)
	elif StringName(reward_face) == REWARD_ARTIFACT_FACE_ID:
		_show_artifact_reward_options(owner)
	elif StringName(reward_face) == REWARD_CUBE_FACE_ID:
		_show_cube_reward_options(owner)


func _find_post_battle_reward_die(owner: Node) -> Dice:
	var reward_dice = owner._get_turn_dice(&"reward")
	var fallback_die: Dice = null
	for dice in reward_dice:
		if dice == null:
			continue
		var dice_definition := dice.get_meta(&"definition", null) as DiceDefinition
		if dice_definition == null:
			continue
		if dice_definition.scope == DiceDefinition.Scope.REWARD and fallback_die == null:
			fallback_die = dice
		if dice_definition.dice_name == "reward_cube":
			return dice
	return fallback_die


func _show_ability_reward_options(owner: Node) -> void:
	var options := _build_ability_reward_options(owner, ABILITY_REWARD_OPTIONS_COUNT)
	if options.is_empty():
		print("[Debug][RewardFlow] Не удалось сгенерировать способности для награды.")
		return
	_render_ability_reward_cards(owner, options)
	owner._is_awaiting_ability_reward_selection = true
	var ability_names: PackedStringArray = PackedStringArray()
	for entry in options:
		var ability := entry.get("ability") as AbilityDefinition
		if ability != null:
			ability_names.append(ability.display_name)
	print("[Debug][RewardFlow] Выпали способности: %s." % ", ".join(ability_names))


func _show_ability_upgrade_options(owner: Node) -> void:
	var options := _build_ability_upgrade_options(owner)
	if options.is_empty():
		print("[Debug][RewardFlow] Не удалось сгенерировать улучшения способностей.")
		return
	_render_ability_reward_cards(owner, options)
	owner._is_awaiting_ability_reward_selection = true
	var ability_names: PackedStringArray = PackedStringArray()
	for entry in options:
		var ability := entry.get("ability") as AbilityDefinition
		if ability != null:
			ability_names.append(ability.display_name)
	print("[Debug][RewardFlow] Выпали улучшения способности: %s." % ", ".join(ability_names))


func _show_artifact_reward_options(owner: Node) -> void:
	var options := _build_artifact_reward_options(owner, ARTIFACT_REWARD_OPTIONS_COUNT)
	if options.is_empty():
		print("[Debug][RewardFlow] Не удалось сгенерировать артефакты для награды.")
		return
	_render_artifact_reward_cards(owner, options)
	owner._is_awaiting_ability_reward_selection = true
	var artifact_names: PackedStringArray = PackedStringArray()
	for entry in options:
		var artifact := entry.get("artifact") as ArtifactDefinition
		if artifact != null:
			artifact_names.append(artifact.display_name)
	print("[Debug][RewardFlow] Выпали артефакты: %s." % ", ".join(artifact_names))


func _show_cube_reward_options(owner: Node) -> void:
	var options := _build_cube_reward_options(owner, CUBE_REWARD_OPTIONS_COUNT)
	if options.is_empty():
		print("[Debug][RewardFlow] Не удалось сгенерировать кубы для награды.")
		return
	_render_cube_reward_cards(owner, options)
	owner._is_awaiting_ability_reward_selection = true
	var cube_names: PackedStringArray = PackedStringArray()
	for entry in options:
		var reward_cube := entry.get("cube") as DiceDefinition
		if reward_cube != null:
			cube_names.append(reward_cube.dice_name)
	print("[Debug][RewardFlow] Выпали кубы: %s." % ", ".join(cube_names))


func _build_ability_reward_options(owner: Node, count: int) -> Array[Dictionary]:
	var player = owner.battle_room_data.player_instance if owner.battle_room_data != null else null
	if player == null:
		return []
	var available_abilities := _load_player_reward_abilities()
	if available_abilities.is_empty():
		return []
	var owned_ability_ids := _collect_owned_ability_ids(player)
	var generated: Array[Dictionary] = []
	var offered_ability_ids := {}
	for _index in count:
		var target_rarity := _roll_reward_rarity(owner)
		var ability := _pick_ability_by_rarity_with_fallback(available_abilities, target_rarity, owned_ability_ids, offered_ability_ids, owner)
		if ability == null:
			continue
		offered_ability_ids[ability.ability_id] = true
		generated.append({
			"ability": ability,
			"rolled_rarity": target_rarity,
			"reward_kind": "new_ability",
		})
	return generated


func _build_ability_upgrade_options(owner: Node) -> Array[Dictionary]:
	var player = owner.battle_room_data.player_instance if owner.battle_room_data != null else null
	if player == null:
		return []
	var ability_catalog := _load_ability_catalog()
	var upgradable_entries: Array[Dictionary] = []
	for ability_index in range(player.ability_loadout.size()):
		var base_ability := player.ability_loadout[ability_index] as AbilityDefinition
		if base_ability == null:
			continue
		var upgrade_options := _resolve_follow_up_abilities(base_ability, ability_catalog)
		if upgrade_options.is_empty():
			continue
		upgradable_entries.append({
			"ability_index": ability_index,
			"base_ability": base_ability,
			"upgrade_options": upgrade_options,
		})
	if upgradable_entries.is_empty():
		return []
	var rolled_entry: Dictionary = upgradable_entries[owner._ability_reward_rng.randi_range(0, upgradable_entries.size() - 1)]
	var rolled_index := int(rolled_entry.get("ability_index", -1))
	var rolled_options: Array[AbilityDefinition] = []
	var rolled_options_raw = rolled_entry.get("upgrade_options", [])
	for option in rolled_options_raw:
		var typed_option := option as AbilityDefinition
		if typed_option != null:
			rolled_options.append(typed_option)
	var generated: Array[Dictionary] = []
	for option in rolled_options:
		if option == null:
			continue
		generated.append({
			"ability": option,
			"reward_kind": "ability_upgrade",
			"replace_index": rolled_index,
		})
	return generated


func _build_artifact_reward_options(owner: Node, count: int) -> Array[Dictionary]:
	var player = owner.battle_room_data.player_instance if owner.battle_room_data != null else null
	if player == null:
		return []
	var available_artifacts := _load_artifact_definitions()
	if available_artifacts.is_empty():
		return []
	var blocked_unique_artifact_ids := _collect_owned_unique_artifact_ids(player)
	var generated: Array[Dictionary] = []
	for _index in count:
		var target_rarity := _roll_artifact_reward_rarity(owner)
		var artifact := _pick_artifact_by_rarity_with_fallback(available_artifacts, target_rarity, blocked_unique_artifact_ids, owner)
		if artifact == null:
			continue
		if _is_unique_artifact(artifact):
			blocked_unique_artifact_ids[artifact.artifact_id] = true
		generated.append({
			"artifact": artifact,
			"rolled_rarity": target_rarity,
			"reward_kind": "artifact",
		})
	return generated


func _build_cube_reward_options(owner: Node, count: int) -> Array[Dictionary]:
	var player = owner.battle_room_data.player_instance if owner.battle_room_data != null else null
	if player == null:
		return []
	var available_cubes := _load_reward_dice_definitions()
	if available_cubes.is_empty():
		return []
	var blocked_unique_cube_ids := _collect_owned_unique_cube_ids(player)
	var generated: Array[Dictionary] = []
	for _index in count:
		var target_rarity := _roll_cube_reward_rarity(owner)
		var reward_cube := _pick_cube_by_rarity_with_fallback(available_cubes, target_rarity, blocked_unique_cube_ids, owner)
		if reward_cube == null:
			continue
		if _is_unique_cube(reward_cube):
			blocked_unique_cube_ids[reward_cube.dice_name] = true
		generated.append({
			"cube": reward_cube,
			"rolled_rarity": target_rarity,
			"reward_kind": "cube",
		})
	return generated


func _load_player_reward_abilities() -> Array[AbilityDefinition]:
	var abilities: Array[AbilityDefinition] = []
	for ability in _load_all_abilities_from_directory():
		if ability.owner_scope != AbilityDefinition.OwnerScope.PLAYER and ability.owner_scope != AbilityDefinition.OwnerScope.ANY:
			continue
		abilities.append(ability)
	return abilities


func _load_ability_catalog() -> Dictionary:
	var catalog := {}
	for ability in _load_all_abilities_from_directory():
		if ability == null:
			continue
		catalog[ability.resource_path] = ability
	return catalog


func _load_all_abilities_from_directory() -> Array[AbilityDefinition]:
	var abilities: Array[AbilityDefinition] = []
	var dir := DirAccess.open(ABILITY_DEFINITIONS_DIRECTORY)
	if dir == null:
		push_warning("Не удалось открыть каталог способностей: %s" % ABILITY_DEFINITIONS_DIRECTORY)
		return abilities
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var path := "%s/%s" % [ABILITY_DEFINITIONS_DIRECTORY, file_name]
		var ability := ResourceLoader.load(path) as AbilityDefinition
		if ability == null:
			continue
		abilities.append(ability)
	dir.list_dir_end()
	return abilities


func _load_artifact_definitions() -> Array[ArtifactDefinition]:
	var artifacts: Array[ArtifactDefinition] = []
	var dir := DirAccess.open(ARTIFACT_DEFINITIONS_DIRECTORY)
	if dir == null:
		push_warning("Не удалось открыть каталог артефактов: %s" % ARTIFACT_DEFINITIONS_DIRECTORY)
		return artifacts
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var path := "%s/%s" % [ARTIFACT_DEFINITIONS_DIRECTORY, file_name]
		var artifact := ResourceLoader.load(path) as ArtifactDefinition
		if artifact == null or not artifact.is_valid_definition():
			continue
		artifacts.append(artifact)
	dir.list_dir_end()
	return artifacts


func _load_reward_dice_definitions() -> Array[DiceDefinition]:
	var cubes: Array[DiceDefinition] = []
	var dir := DirAccess.open(DICE_DEFINITIONS_DIRECTORY)
	if dir == null:
		push_warning("Не удалось открыть каталог кубов: %s" % DICE_DEFINITIONS_DIRECTORY)
		return cubes
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var path := "%s/%s" % [DICE_DEFINITIONS_DIRECTORY, file_name]
		var reward_cube := ResourceLoader.load(path) as DiceDefinition
		if reward_cube == null:
			continue
		if reward_cube.scope == DiceDefinition.Scope.MONEY or reward_cube.scope == DiceDefinition.Scope.SYSTEM:
			continue
		if reward_cube.get_face_count() <= 0:
			continue
		cubes.append(reward_cube)
	dir.list_dir_end()
	return cubes


func _resolve_follow_up_abilities(base_ability: AbilityDefinition, ability_catalog: Dictionary) -> Array[AbilityDefinition]:
	var resolved: Array[AbilityDefinition] = []
	if base_ability == null:
		return resolved
	for follow_up_id in base_ability.follow_up_ability_ids:
		var key := str(follow_up_id)
		if key.is_empty():
			continue
		var follow_up_ability := ability_catalog.get(key, null) as AbilityDefinition
		if follow_up_ability == null:
			continue
		resolved.append(follow_up_ability)
	return resolved


func _collect_owned_ability_ids(player: Player) -> Dictionary:
	var owned := {}
	if player == null:
		return owned
	for ability in player.ability_loadout:
		if ability == null:
			continue
		owned[ability.ability_id] = true
	return owned


func _collect_owned_unique_artifact_ids(player: Player) -> Dictionary:
	var owned_unique := {}
	if player == null:
		return owned_unique
	for artifact in player.get_active_artifact_definitions():
		if artifact == null or not _is_unique_artifact(artifact):
			continue
		owned_unique[artifact.artifact_id] = true
	return owned_unique


func _collect_owned_unique_cube_ids(player: Player) -> Dictionary:
	var owned_unique := {}
	if player == null:
		return owned_unique
	var all_runtime_cubes: Array[DiceDefinition] = []
	all_runtime_cubes.append_array(player.dice_loadout)
	all_runtime_cubes.append_array(player.runtime_cube_global_map)
	all_runtime_cubes.append_array(player.get_active_reward_cubes())
	all_runtime_cubes.append_array(player.runtime_event_cubes)
	for reward_cube in all_runtime_cubes:
		if reward_cube == null or not _is_unique_cube(reward_cube):
			continue
		owned_unique[reward_cube.dice_name] = true
	return owned_unique


func _roll_reward_rarity(owner: Node) -> int:
	var total_weight := RARITY_COMMON_WEIGHT + RARITY_UNCOMMON_WEIGHT + RARITY_RARE_WEIGHT + RARITY_UNIQUE_WEIGHT
	var roll = owner._ability_reward_rng.randf_range(0.0, total_weight)
	if roll < RARITY_COMMON_WEIGHT:
		return AbilityDefinition.Rarity.COMMON
	roll -= RARITY_COMMON_WEIGHT
	if roll < RARITY_UNCOMMON_WEIGHT:
		return AbilityDefinition.Rarity.UNCOMMON
	roll -= RARITY_UNCOMMON_WEIGHT
	if roll < RARITY_RARE_WEIGHT:
		return AbilityDefinition.Rarity.RARE
	return AbilityDefinition.Rarity.UNIQUE


func _roll_artifact_reward_rarity(owner: Node) -> StringName:
	var total_weight := ARTIFACT_RARITY_COMMON_WEIGHT + ARTIFACT_RARITY_UNCOMMON_WEIGHT + ARTIFACT_RARITY_RARE_WEIGHT + ARTIFACT_RARITY_UNIQUE_WEIGHT
	var roll = owner._ability_reward_rng.randf_range(0.0, total_weight)
	if roll < ARTIFACT_RARITY_COMMON_WEIGHT:
		return &"common"
	roll -= ARTIFACT_RARITY_COMMON_WEIGHT
	if roll < ARTIFACT_RARITY_UNCOMMON_WEIGHT:
		return &"uncommon"
	roll -= ARTIFACT_RARITY_UNCOMMON_WEIGHT
	if roll < ARTIFACT_RARITY_RARE_WEIGHT:
		return &"rare"
	return &"unique"


func _roll_cube_reward_rarity(owner: Node) -> int:
	var total_weight := CUBE_RARITY_COMMON_WEIGHT + CUBE_RARITY_UNCOMMON_WEIGHT + CUBE_RARITY_RARE_WEIGHT + CUBE_RARITY_UNIQUE_WEIGHT
	var roll = owner._ability_reward_rng.randf_range(0.0, total_weight)
	if roll < CUBE_RARITY_COMMON_WEIGHT:
		return DiceDefinition.Rarity.COMMON
	roll -= CUBE_RARITY_COMMON_WEIGHT
	if roll < CUBE_RARITY_UNCOMMON_WEIGHT:
		return DiceDefinition.Rarity.UNCOMMON
	roll -= CUBE_RARITY_UNCOMMON_WEIGHT
	if roll < CUBE_RARITY_RARE_WEIGHT:
		return DiceDefinition.Rarity.RARE
	return DiceDefinition.Rarity.UNIQUE


func _pick_ability_by_rarity_with_fallback(
	abilities: Array[AbilityDefinition],
	start_rarity: int,
	owned_ability_ids: Dictionary,
	offered_ability_ids: Dictionary,
	owner: Node
) -> AbilityDefinition:
	for rarity in range(start_rarity, AbilityDefinition.Rarity.COMMON - 1, -1):
		var candidates: Array[AbilityDefinition] = []
		for ability in abilities:
			if ability == null:
				continue
			if ability.rarity != rarity:
				continue
			if owned_ability_ids.has(ability.ability_id) or offered_ability_ids.has(ability.ability_id):
				continue
			candidates.append(ability)
		if candidates.is_empty():
			continue
		return candidates[owner._ability_reward_rng.randi_range(0, candidates.size() - 1)]
	return null


func _pick_artifact_by_rarity_with_fallback(
	artifacts: Array[ArtifactDefinition],
	start_rarity: StringName,
	blocked_unique_artifact_ids: Dictionary,
	owner: Node
) -> ArtifactDefinition:
	for rarity in _build_artifact_rarity_fallback_chain(start_rarity):
		var candidates: Array[ArtifactDefinition] = []
		for artifact in artifacts:
			if artifact == null or artifact.rarity != rarity:
				continue
			if _is_unique_artifact(artifact) and blocked_unique_artifact_ids.has(artifact.artifact_id):
				continue
			candidates.append(artifact)
		if candidates.is_empty():
			continue
		return candidates[owner._ability_reward_rng.randi_range(0, candidates.size() - 1)]
	return null


func _pick_cube_by_rarity_with_fallback(
	cubes: Array[DiceDefinition],
	start_rarity: int,
	blocked_unique_cube_ids: Dictionary,
	owner: Node
) -> DiceDefinition:
	for rarity in range(start_rarity, DiceDefinition.Rarity.COMMON - 1, -1):
		var candidates: Array[DiceDefinition] = []
		for reward_cube in cubes:
			if reward_cube == null or reward_cube.rarity != rarity:
				continue
			if _is_unique_cube(reward_cube) and blocked_unique_cube_ids.has(reward_cube.dice_name):
				continue
			candidates.append(reward_cube)
		if candidates.is_empty():
			continue
		return candidates[owner._ability_reward_rng.randi_range(0, candidates.size() - 1)]
	return null


func _build_artifact_rarity_fallback_chain(start_rarity: StringName) -> Array[StringName]:
	var ordered: Array[StringName] = [&"common", &"uncommon", &"rare", &"unique"]
	var start_index := maxi(ordered.find(start_rarity), 0)
	var chain: Array[StringName] = []
	for index in range(start_index, -1, -1):
		chain.append(ordered[index])
	return chain


func _is_unique_artifact(artifact: ArtifactDefinition) -> bool:
	return artifact != null and artifact.rarity == &"unique"


func _is_unique_cube(reward_cube: DiceDefinition) -> bool:
	return reward_cube != null and reward_cube.rarity == DiceDefinition.Rarity.UNIQUE


func _compute_reward_card_spacing_x(owner: Node) -> float:
	if owner._ability_reward_template == null:
		return ABILITY_REWARD_CARD_MIN_SPACING_X
	var frame_base := owner._ability_reward_template.get_node_or_null(^"ability_frame_base") as MeshInstance3D
	if frame_base == null or frame_base.mesh == null:
		return ABILITY_REWARD_CARD_MIN_SPACING_X
	var card_size := frame_base.mesh.get_aabb().size
	var world_scale := frame_base.global_transform.basis.get_scale()
	var card_width := card_size.x * absf(world_scale.x)
	if card_width <= 0.0:
		return ABILITY_REWARD_CARD_MIN_SPACING_X
	return maxf(ABILITY_REWARD_CARD_MIN_SPACING_X, card_width + ABILITY_REWARD_CARD_GAP_X)


func _compute_artifact_reward_spacing_x(owner: Node) -> float:
	if owner._artifact_reward_template == null or owner._artifact_reward_template.mesh == null:
		return ARTIFACT_REWARD_MIN_SPACING_X
	var frame_size = owner._artifact_reward_template.mesh.get_aabb().size
	var world_scale = owner._artifact_reward_template.global_transform.basis.get_scale()
	var frame_width = frame_size.x * absf(world_scale.x)
	if frame_width <= 0.0:
		return ARTIFACT_REWARD_MIN_SPACING_X
	return maxf(ARTIFACT_REWARD_MIN_SPACING_X, frame_width + ARTIFACT_REWARD_GAP_X)


func _render_ability_reward_cards(owner: Node, entries: Array[Dictionary]) -> void:
	_clear_cube_reward_cards(owner)
	_clear_artifact_reward_cards(owner)
	_clear_ability_reward_cards(owner)
	if owner._ability_reward_template == null:
		return
	owner._ability_reward_template.visible = false
	owner._ability_reward_entries.clear()
	if entries.is_empty():
		return
	var spacing_x := _compute_reward_card_spacing_x(owner)
	var offsets = owner._build_centered_offsets(entries.size(), spacing_x)
	var template_basis = owner._ability_reward_template.transform.basis
	var template_origin = owner._ability_reward_template.transform.origin
	for index in entries.size():
		var card_root = owner._ability_reward_template if index == 0 else (owner._ability_reward_template.duplicate() as Node3D)
		if card_root.get_parent() == null:
			owner.add_child(card_root)
		card_root.visible = true
		card_root.transform = Transform3D(
			template_basis,
			template_origin + Vector3(offsets[index], 0.0, 0.0)
		)
		var reward_entry: Dictionary = entries[index]
		var ability := reward_entry.get("ability") as AbilityDefinition
		_apply_reward_card_visual(owner, card_root, ability)
		reward_entry["node"] = card_root
		owner._ability_reward_entries.append(reward_entry)
		if index > 0:
			owner._generated_ability_reward_nodes.append(card_root)


func _render_artifact_reward_cards(owner: Node, entries: Array[Dictionary]) -> void:
	_clear_cube_reward_cards(owner)
	_clear_ability_reward_cards(owner)
	_clear_artifact_reward_cards(owner)
	if owner._ability_reward_template == null:
		return
	if owner._artifact_reward_template != null:
		owner._artifact_reward_template.visible = false
	owner._ability_reward_template.visible = false
	owner._artifact_reward_entries.clear()
	if entries.is_empty():
		return
	var spacing_x := _compute_reward_card_spacing_x(owner)
	var offsets = owner._build_centered_offsets(entries.size(), spacing_x)
	var template_basis = owner._ability_reward_template.transform.basis
	var template_origin = owner._ability_reward_template.transform.origin
	for index in entries.size():
		var card_root = owner._ability_reward_template if index == 0 else (owner._ability_reward_template.duplicate() as Node3D)
		if card_root.get_parent() == null:
			owner.add_child(card_root)
		card_root.visible = true
		card_root.transform = Transform3D(
			template_basis,
			template_origin + Vector3(offsets[index], 0.0, 0.0)
		)
		var reward_entry: Dictionary = entries[index]
		var artifact := reward_entry.get("artifact") as ArtifactDefinition
		_apply_artifact_reward_visual(owner, card_root, artifact)
		reward_entry["node"] = card_root
		owner._artifact_reward_entries.append(reward_entry)
		if index > 0:
			owner._generated_artifact_reward_nodes.append(card_root)


func _render_cube_reward_cards(owner: Node, entries: Array[Dictionary]) -> void:
	_clear_ability_reward_cards(owner)
	_clear_artifact_reward_cards(owner)
	_clear_cube_reward_cards(owner)
	if owner._ability_reward_template == null:
		return
	if owner._artifact_reward_template != null:
		owner._artifact_reward_template.visible = false
	if owner._cube_reward_template != null:
		owner._cube_reward_template.visible = false
	owner._ability_reward_template.visible = false
	owner._cube_reward_entries.clear()
	if entries.is_empty():
		return
	var spacing_x := _compute_reward_card_spacing_x(owner)
	var offsets = owner._build_centered_offsets(entries.size(), spacing_x)
	var template_basis = owner._ability_reward_template.transform.basis
	var template_origin = owner._ability_reward_template.transform.origin
	for index in entries.size():
		var card_root = owner._ability_reward_template if index == 0 else (owner._ability_reward_template.duplicate() as Node3D)
		if card_root.get_parent() == null:
			owner.add_child(card_root)
		card_root.visible = true
		card_root.transform = Transform3D(
			template_basis,
			template_origin + Vector3(offsets[index], 0.0, 0.0)
		)
		var reward_entry: Dictionary = entries[index]
		var reward_cube := reward_entry.get("cube") as DiceDefinition
		_apply_cube_reward_visual(owner, card_root, reward_cube)
		reward_entry["node"] = card_root
		owner._cube_reward_entries.append(reward_entry)
		if index > 0:
			owner._generated_cube_reward_nodes.append(card_root)


func _apply_reward_card_visual(owner: Node, card_root: Node3D, ability: AbilityDefinition) -> void:
	if card_root == null:
		return
	_remove_embedded_artifact_reward_frame(card_root)
	var icon_mesh := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if icon_mesh != null:
		icon_mesh.visible = true
	if icon_mesh != null and ability != null and ability.icon != null:
		owner._apply_texture_to_mesh(icon_mesh, ability.icon)
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = ability.display_name if ability != null else ""
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = ability.description if ability != null else ""


func _apply_artifact_reward_visual(owner: Node, card_root: Node3D, artifact: ArtifactDefinition) -> void:
	if card_root == null:
		return
	_remove_embedded_cube_reward_preview(card_root)
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = artifact.display_name if artifact != null else ""
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = artifact.description if artifact != null else ""
	var ability_icon := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if ability_icon != null:
		ability_icon.visible = false
	var icon_frame := _ensure_embedded_artifact_reward_frame(owner, card_root, ability_icon)
	if icon_frame == null:
		return
	var icon_mesh := icon_frame.get_node_or_null(^"artefact_icon_reward") as MeshInstance3D
	if icon_mesh != null and artifact != null and artifact.sprite != null:
		owner._apply_texture_to_mesh(icon_mesh, artifact.sprite)


func _apply_cube_reward_visual(owner: Node, card_root: Node3D, reward_cube: DiceDefinition) -> void:
	if card_root == null:
		return
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = reward_cube.dice_name if reward_cube != null else ""
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = _build_cube_reward_description(reward_cube)
	var ability_icon := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if ability_icon != null:
		ability_icon.visible = false
	var icon_frame := _ensure_embedded_artifact_reward_frame(owner, card_root, ability_icon)
	if icon_frame == null:
		return
	_remove_embedded_cube_reward_preview(card_root)
	var preview_cube := _spawn_cube_reward_preview(owner, reward_cube)
	if preview_cube == null:
		return
	var preview_rotation_radians := Vector3(
		deg_to_rad(CUBE_REWARD_PREVIEW_ROTATION_DEGREES.x),
		deg_to_rad(CUBE_REWARD_PREVIEW_ROTATION_DEGREES.y),
		deg_to_rad(CUBE_REWARD_PREVIEW_ROTATION_DEGREES.z)
	)
	preview_cube.transform = Transform3D(
		Basis.from_euler(preview_rotation_radians),
		Vector3(0.0, CUBE_REWARD_PREVIEW_Y_OFFSET, 0.0)
	)
	preview_cube.scale = CUBE_REWARD_PREVIEW_SCALE
	icon_frame.add_child(preview_cube)


func _build_cube_reward_description(reward_cube: DiceDefinition) -> String:
	if reward_cube == null:
		return ""
	var scope_name := _resolve_scope_name(reward_cube.scope)
	return "Редкость: %s\nТип: %s" % [_resolve_dice_rarity_name(reward_cube.rarity), scope_name]


func _resolve_scope_name(scope: int) -> String:
	match scope:
		DiceDefinition.Scope.COMBAT:
			return "Куб боя"
		DiceDefinition.Scope.GLOBAL_MAP:
			return "Куб карты"
		DiceDefinition.Scope.REWARD:
			return "Куб награды"
		DiceDefinition.Scope.EVENT:
			return "Куб события"
		DiceDefinition.Scope.MONEY:
			return "Куб денег"
		_:
			return "Куб"


func _resolve_dice_rarity_name(rarity: int) -> String:
	match rarity:
		DiceDefinition.Rarity.UNCOMMON:
			return "Необычный"
		DiceDefinition.Rarity.RARE:
			return "Редкий"
		DiceDefinition.Rarity.UNIQUE:
			return "Уникальный"
		_:
			return "Обычный"


func _spawn_cube_reward_preview(owner: Node, reward_cube: DiceDefinition) -> Dice:
	if owner._cube_reward_template == null:
		return null
	var preview_cube := owner._cube_reward_template.duplicate() as Dice
	if preview_cube == null:
		return null
	preview_cube.name = "cube_reward_preview"
	preview_cube.definition = reward_cube
	preview_cube.freeze = true
	preview_cube.sleeping = true
	preview_cube.lock_rotation = true
	preview_cube.input_ray_pickable = false
	preview_cube.collision_layer = 0
	preview_cube.collision_mask = 0
	preview_cube.set_physics_process(false)
	preview_cube.linear_velocity = Vector3.ZERO
	preview_cube.angular_velocity = Vector3.ZERO
	return preview_cube


func _ensure_embedded_artifact_reward_frame(owner: Node, card_root: Node3D, ability_icon: MeshInstance3D) -> MeshInstance3D:
	if owner._artifact_reward_template == null or card_root == null:
		return null
	var embedded_frame := card_root.get_node_or_null(^"artifact_reward_icon_frame") as MeshInstance3D
	if embedded_frame == null:
		embedded_frame = owner._artifact_reward_template.duplicate() as MeshInstance3D
		if embedded_frame == null:
			return null
		embedded_frame.name = "artifact_reward_icon_frame"
		card_root.add_child(embedded_frame)
	embedded_frame.visible = true
	if ability_icon != null:
		embedded_frame.transform = ability_icon.transform
	return embedded_frame


func _remove_embedded_artifact_reward_frame(card_root: Node3D) -> void:
	if card_root == null:
		return
	var embedded_frame := card_root.get_node_or_null(^"artifact_reward_icon_frame") as MeshInstance3D
	if embedded_frame != null and is_instance_valid(embedded_frame):
		embedded_frame.queue_free()


func _remove_embedded_cube_reward_preview(card_root: Node3D) -> void:
	if card_root == null:
		return
	var preview_cube := card_root.find_child("cube_reward_preview", true, false) as Dice
	if preview_cube != null and is_instance_valid(preview_cube):
		preview_cube.queue_free()


func _clear_ability_reward_cards(owner: Node) -> void:
	for generated_node in owner._generated_ability_reward_nodes:
		if generated_node != null and is_instance_valid(generated_node):
			generated_node.queue_free()
	owner._generated_ability_reward_nodes.clear()
	owner._ability_reward_entries.clear()
	if owner._ability_reward_template != null:
		owner._ability_reward_template.visible = false
	_update_reward_waiting_state(owner)


func _clear_artifact_reward_cards(owner: Node) -> void:
	for generated_node in owner._generated_artifact_reward_nodes:
		if generated_node != null and is_instance_valid(generated_node):
			generated_node.queue_free()
	owner._generated_artifact_reward_nodes.clear()
	owner._artifact_reward_entries.clear()
	if owner._artifact_reward_template != null:
		owner._artifact_reward_template.visible = false
	_update_reward_waiting_state(owner)


func _clear_cube_reward_cards(owner: Node) -> void:
	for generated_node in owner._generated_cube_reward_nodes:
		if generated_node != null and is_instance_valid(generated_node):
			generated_node.queue_free()
	owner._generated_cube_reward_nodes.clear()
	owner._cube_reward_entries.clear()
	if owner._cube_reward_template != null:
		owner._cube_reward_template.visible = false
	_update_reward_waiting_state(owner)


func _resolve_reward_click(owner: Node, screen_point: Vector2) -> Dictionary:
	var ability_entry := _resolve_ability_reward_click(owner, screen_point)
	if not ability_entry.is_empty():
		return ability_entry
	var artifact_entry := _resolve_artifact_reward_click(owner, screen_point)
	if not artifact_entry.is_empty():
		return artifact_entry
	return _resolve_cube_reward_click(owner, screen_point)


func _resolve_ability_reward_click(owner: Node, screen_point: Vector2) -> Dictionary:
	for index in range(owner._ability_reward_entries.size() - 1, -1, -1):
		var entry = owner._ability_reward_entries[index]
		var card_node := entry.get("node") as Node3D
		if card_node == null:
			continue
		var frame_mesh := card_node.get_node_or_null(^"ability_frame_base") as MeshInstance3D
		if owner._screen_point_hits_mesh(frame_mesh, screen_point):
			return entry
	return {}


func _resolve_artifact_reward_click(owner: Node, screen_point: Vector2) -> Dictionary:
	for index in range(owner._artifact_reward_entries.size() - 1, -1, -1):
		var entry = owner._artifact_reward_entries[index]
		var card_node := entry.get("node") as Node3D
		if card_node == null:
			continue
		var frame_mesh := card_node.get_node_or_null(^"ability_frame_base") as MeshInstance3D
		if owner._screen_point_hits_mesh(frame_mesh, screen_point):
			return entry
	return {}


func _resolve_cube_reward_click(owner: Node, screen_point: Vector2) -> Dictionary:
	for index in range(owner._cube_reward_entries.size() - 1, -1, -1):
		var entry = owner._cube_reward_entries[index]
		var card_node := entry.get("node") as Node3D
		if card_node == null:
			continue
		var frame_mesh := card_node.get_node_or_null(^"ability_frame_base") as MeshInstance3D
		if owner._screen_point_hits_mesh(frame_mesh, screen_point):
			return entry
	return {}


func _select_reward_entry(owner: Node, entry: Dictionary) -> void:
	var reward_kind := StringName(str(entry.get("reward_kind", "")))
	if reward_kind == &"artifact":
		_select_artifact_reward(owner, entry)
		return
	if reward_kind == &"cube":
		_select_cube_reward(owner, entry)
		return
	_select_ability_reward(owner, entry)


func _select_ability_reward(owner: Node, entry: Dictionary) -> void:
	var selected_ability := entry.get("ability") as AbilityDefinition
	if selected_ability == null or owner.battle_room_data == null or owner.battle_room_data.player_instance == null:
		return
	var player = owner.battle_room_data.player_instance
	var reward_kind := str(entry.get("reward_kind", "new_ability"))
	if reward_kind == "ability_upgrade":
		var replace_index := int(entry.get("replace_index", -1))
		if replace_index < 0 or replace_index >= player.ability_loadout.size():
			_clear_ability_reward_cards(owner)
			return
		player.ability_loadout[replace_index] = selected_ability
	else:
		for owned in player.ability_loadout:
			if owned != null and owned.ability_id == selected_ability.ability_id:
				_clear_ability_reward_cards(owner)
				return
		player.ability_loadout.append(selected_ability)
	owner.battle_room_data.player_view.abilities = player.ability_loadout.duplicate()
	print("[Debug][RewardFlow] Игрок выбрал способность: %s." % selected_ability.display_name)
	owner._player_ability_frame_states.clear()
	owner._player_ability_slot_states.clear()
	owner._apply_ability_frames(
		owner.battle_room_data.get_player_abilities(),
		owner._player_ability_template,
		owner._generated_player_ability_frames,
		true
	)
	_clear_ability_reward_cards(owner)
	_return_to_saved_global_map(owner)


func _select_artifact_reward(owner: Node, entry: Dictionary) -> void:
	var selected_artifact := entry.get("artifact") as ArtifactDefinition
	if selected_artifact == null or owner.battle_room_data == null or owner.battle_room_data.player_instance == null:
		return
	var player = owner.battle_room_data.player_instance
	if _is_unique_artifact(selected_artifact):
		for owned_artifact in player.get_active_artifact_definitions():
			if owned_artifact != null and owned_artifact.artifact_id == selected_artifact.artifact_id:
				_clear_artifact_reward_cards(owner)
				return
	player.grant_artifact(selected_artifact)
	owner._apply_player_artifacts()
	print("[Debug][RewardFlow] Игрок выбрал артефакт: %s." % selected_artifact.display_name)
	_clear_artifact_reward_cards(owner)
	_return_to_saved_global_map(owner)


func _select_cube_reward(owner: Node, entry: Dictionary) -> void:
	var selected_cube := entry.get("cube") as DiceDefinition
	if selected_cube == null or owner.battle_room_data == null or owner.battle_room_data.player_instance == null:
		return
	var player = owner.battle_room_data.player_instance
	if _is_unique_cube(selected_cube):
		if _player_has_unique_cube(player, selected_cube.dice_name):
			_clear_cube_reward_cards(owner)
			return
	player.grant_runtime_cube(selected_cube)
	print("[Debug][RewardFlow] Игрок выбрал куб: %s (scope=%d)." % [selected_cube.dice_name, selected_cube.scope])
	_clear_cube_reward_cards(owner)
	_return_to_saved_global_map(owner)


func _player_has_unique_cube(player: Player, dice_name: String) -> bool:
	if player == null:
		return false
	var all_runtime_cubes: Array[DiceDefinition] = []
	all_runtime_cubes.append_array(player.dice_loadout)
	all_runtime_cubes.append_array(player.runtime_cube_global_map)
	all_runtime_cubes.append_array(player.get_active_reward_cubes())
	all_runtime_cubes.append_array(player.runtime_event_cubes)
	for runtime_cube in all_runtime_cubes:
		if runtime_cube == null:
			continue
		if runtime_cube.dice_name == dice_name:
			return true
	return false


func _update_reward_waiting_state(owner: Node) -> void:
	owner._is_awaiting_ability_reward_selection = not owner._ability_reward_entries.is_empty() or not owner._artifact_reward_entries.is_empty() or not owner._cube_reward_entries.is_empty()


func _return_to_saved_global_map(owner: Node) -> void:
	if owner == null:
		return
	var tree := owner.get_tree()
	if tree == null:
		return
	var map_scene_path := GlobalMapRuntimeState.load_map_scene_path()
	if map_scene_path.is_empty():
		push_warning("Failed to open global map scene: runtime map scene path is empty.")
		return
	var result := tree.change_scene_to_file(map_scene_path)
	if result != OK:
		push_warning("Failed to open global map scene: %s" % map_scene_path)
