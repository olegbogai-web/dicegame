extends RefCounted
class_name PostBattleRewardFlow

const Dice = preload("res://content/dice/dice.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")

const POST_BATTLE_REWARD_DICE_SIZE_MULTIPLIER := Vector3(4.0, 4.0, 4.0)
const POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER := 0.75
const POST_BATTLE_REWARD_DICE_DELAY_SECONDS := 1.0
const POST_MONEY_REWARD_RETURN_DELAY_SECONDS := 2.0
const REWARD_CARD_NEW_FACE_ID := &"card_+"
const REWARD_CARD_UP_FACE_ID := &"card_up"
const REWARD_ARTIFACT_FACE_ID := &"artifact_+"
const REWARD_CUBE_FACE_ID := &"cube_+"
const REWARD_MONEY_FACE_ID := &"money"
const BONUS_MONEY_THROW_OWNER := &"reward_bonus_money"
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
const CUBE_REWARD_VISUAL_ROTATION_DEGREES := Vector3(45.0, 10.0, -120.0)
const CUBE_REWARD_VISUAL_POSITION_OFFSET := Vector3(0.0, 0.3, 0.0)
const CUBE_REWARD_VISUAL_SCALE_MULTIPLIER := Vector3(1.5, 1.5, 1.5)
const BASE_CUBE_SCENE_PATH := "res://content/resources/base_cube.tscn"
const GLOBAL_MAP_SCENE_PATH := "res://scenes/global_map_room.tscn"


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
	var reward_cubes = player.runtime_reward_cubes
	var money_cubes = player.runtime_money_cubes
	if reward_cubes.is_empty() and money_cubes.is_empty():
		return
	var requests: Array[DiceThrowRequest] = []
	for reward_cube in reward_cubes:
		if reward_cube != null:
			requests.append(owner._build_dice_throw_request(reward_cube, {"owner": &"reward"}))
	for money_cube in money_cubes:
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
	var all_reward_dice = owner._get_turn_dice(&"reward")
	var reward_dice := _find_post_battle_reward_die(owner)
	if reward_dice == null and all_reward_dice.is_empty():
		return
	for dice in all_reward_dice:
		if dice == null or not dice.has_completed_first_stop():
			return
	owner._has_processed_post_battle_reward_result = true
	var reward_face := ""
	if reward_dice != null:
		var reward_top_face := reward_dice.get_top_face()
		if reward_top_face != null:
			reward_face = reward_top_face.text_value
	var is_money_reward_face := StringName(reward_face) == REWARD_MONEY_FACE_ID
	await _grant_money_from_reward_rolls(owner, all_reward_dice, is_money_reward_face)
	print("[Debug][RewardFlow] На кубе награды выпало: %s." % reward_face)
	if StringName(reward_face) == REWARD_CARD_NEW_FACE_ID:
		_show_ability_reward_options(owner)
	elif StringName(reward_face) == REWARD_CARD_UP_FACE_ID:
		_show_ability_upgrade_options(owner)
	elif StringName(reward_face) == REWARD_ARTIFACT_FACE_ID:
		_show_artifact_reward_options(owner)
	elif StringName(reward_face) == REWARD_CUBE_FACE_ID:
		_show_cube_reward_options(owner)
	elif is_money_reward_face:
		await _return_to_saved_global_map(owner, POST_MONEY_REWARD_RETURN_DELAY_SECONDS)


func _find_post_battle_reward_die(owner: Node) -> Dice:
	var reward_dice = owner._get_turn_dice(&"reward")
	for dice in reward_dice:
		if dice == null:
			continue
		var dice_definition := dice.get_meta(&"definition", null) as DiceDefinition
		if dice_definition == null:
			continue
		if dice_definition.dice_name == "reward_cube":
			return dice
	return null


func _grant_money_from_reward_rolls(owner: Node, rolled_dice: Array, roll_bonus_money_cube: bool) -> void:
	if owner == null or owner.battle_room_data == null:
		return
	var player = owner.battle_room_data.player_instance
	if player == null:
		return
	var granted_coins := _sum_money_from_dice_results(rolled_dice)
	var rolled_reward_money_faces := _count_reward_money_faces(rolled_dice)
	if roll_bonus_money_cube and rolled_reward_money_faces > 0:
		granted_coins += await _roll_bonus_coins_from_runtime_money_dice(owner, player.runtime_money_cubes, rolled_reward_money_faces)
	if granted_coins <= 0:
		return
	player.add_coins(granted_coins)
	print("[Debug][RewardFlow] Начислено монет после боя: +%d (итого: %d)." % [granted_coins, player.current_coins])


func _sum_money_from_dice_results(rolled_dice: Array) -> int:
	var granted_coins := 0
	for dice in rolled_dice:
		var typed_dice := dice as Dice
		if typed_dice == null:
			continue
		var top_face := typed_dice.get_top_face()
		if top_face == null:
			continue
		var dice_definition := typed_dice.get_meta(&"definition", null) as DiceDefinition
		if dice_definition == null or dice_definition.scope != DiceDefinition.Scope.MONEY:
			continue
		granted_coins += maxi(top_face.text_value.to_int(), 0)
	return granted_coins


func _count_reward_money_faces(rolled_dice: Array) -> int:
	var money_faces_count := 0
	for dice in rolled_dice:
		var typed_dice := dice as Dice
		if typed_dice == null:
			continue
		var top_face := typed_dice.get_top_face()
		if top_face == null:
			continue
		var dice_definition := typed_dice.get_meta(&"definition", null) as DiceDefinition
		if dice_definition == null or dice_definition.scope != DiceDefinition.Scope.REWARD:
			continue
		if StringName(top_face.text_value) == REWARD_MONEY_FACE_ID:
			money_faces_count += 1
	return money_faces_count


func _roll_bonus_coins_from_runtime_money_dice(owner: Node, money_cubes: Array[DiceDefinition], rolls_count: int) -> int:
	if money_cubes.is_empty() or rolls_count <= 0:
		return 0
	if owner == null or owner._board == null:
		return 0
	var requests: Array[DiceThrowRequest] = []
	for roll_index in rolls_count:
		var source_cube := money_cubes[roll_index % money_cubes.size()]
		if source_cube == null:
			continue
		requests.append(owner._build_dice_throw_request(source_cube, {"owner": BONUS_MONEY_THROW_OWNER}))
	if requests.is_empty():
		return 0
	for request in requests:
		request.extra_size_multiplier = POST_BATTLE_REWARD_DICE_SIZE_MULTIPLIER
	var spawned_dice := owner._board.throw_dice(requests)
	for dice_body in spawned_dice:
		if dice_body == null:
			continue
		dice_body.linear_velocity.y *= POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER
	await _wait_until_all_dice_stopped(owner, spawned_dice)
	var bonus := _sum_money_from_dice_results(spawned_dice)
	print("[Debug][RewardFlow] Дополнительный бросок куба денег: +%d монет." % bonus)
	return bonus


func _wait_until_all_dice_stopped(owner: Node, rolled_dice: Array) -> void:
	if owner == null:
		return
	while true:
		var all_stopped := true
		for dice in rolled_dice:
			var typed_dice := dice as Dice
			if typed_dice == null:
				continue
			if not typed_dice.has_completed_first_stop():
				all_stopped = false
				break
		if all_stopped:
			return
		await owner.get_tree().physics_frame


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
		var dice_definition := entry.get("cube") as DiceDefinition
		if dice_definition != null:
			cube_names.append(dice_definition.dice_name)
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
	var available_cubes := _load_rewardable_cube_definitions()
	if available_cubes.is_empty():
		return []
	var blocked_unique_cube_ids := _collect_owned_unique_cube_ids(player)
	var generated: Array[Dictionary] = []
	for _index in count:
		var target_rarity := _roll_cube_reward_rarity(owner)
		var dice_definition := _pick_cube_by_rarity_with_fallback(available_cubes, target_rarity, blocked_unique_cube_ids, owner)
		if dice_definition == null:
			continue
		if _is_unique_cube(dice_definition):
			blocked_unique_cube_ids[dice_definition.resource_path] = true
		generated.append({
			"cube": dice_definition,
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


func _load_rewardable_cube_definitions() -> Array[DiceDefinition]:
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
		var dice_definition := ResourceLoader.load(path) as DiceDefinition
		if dice_definition == null:
			continue
		if dice_definition.scope == DiceDefinition.Scope.SYSTEM:
			continue
		cubes.append(dice_definition)
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
	var all_scopes := [
		DiceDefinition.Scope.COMBAT,
		DiceDefinition.Scope.GLOBAL_MAP,
		DiceDefinition.Scope.REWARD,
		DiceDefinition.Scope.MONEY,
		DiceDefinition.Scope.EVENT,
	]
	for scope in all_scopes:
		for dice_definition in player.get_runtime_cubes_by_scope(scope):
			if dice_definition == null or not _is_unique_cube(dice_definition):
				continue
			owned_unique[dice_definition.resource_path] = true
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
		for cube in cubes:
			if cube == null or cube.rarity != rarity:
				continue
			if _is_unique_cube(cube) and blocked_unique_cube_ids.has(cube.resource_path):
				continue
			candidates.append(cube)
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


func _is_unique_cube(cube: DiceDefinition) -> bool:
	return cube != null and cube.rarity == DiceDefinition.Rarity.UNIQUE


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
	_clear_ability_reward_cards(owner)
	_clear_cube_reward_cards(owner)
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
		var cube := reward_entry.get("cube") as DiceDefinition
		_apply_cube_reward_visual(owner, card_root, cube)
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
	_remove_embedded_cube_reward_node(card_root)
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


func _apply_cube_reward_visual(owner: Node, card_root: Node3D, cube_definition: DiceDefinition) -> void:
	if card_root == null:
		return
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = cube_definition.display_name if cube_definition != null else ""
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = _build_cube_reward_description(cube_definition)
	var ability_icon := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if ability_icon != null:
		ability_icon.visible = false
	var icon_frame := _ensure_embedded_artifact_reward_frame(owner, card_root, ability_icon)
	if icon_frame == null:
		return
	var icon_mesh := icon_frame.get_node_or_null(^"artefact_icon_reward") as MeshInstance3D
	if icon_mesh != null:
		icon_mesh.visible = false
	_remove_embedded_cube_reward_node(card_root)
	var cube_visual := _build_embedded_cube_reward_node(cube_definition)
	if cube_visual == null:
		return
	icon_frame.add_child(cube_visual)


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


func _build_embedded_cube_reward_node(cube_definition: DiceDefinition) -> Dice:
	var scene := load(BASE_CUBE_SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var cube_node := scene.instantiate() as Dice
	if cube_node == null:
		return null
	cube_node.name = "cube_reward_preview"
	cube_node.definition = cube_definition
	cube_node.extra_size_multiplier = CUBE_REWARD_VISUAL_SCALE_MULTIPLIER
	cube_node.position = CUBE_REWARD_VISUAL_POSITION_OFFSET
	cube_node.rotation_degrees = CUBE_REWARD_VISUAL_ROTATION_DEGREES
	cube_node.freeze = true
	cube_node.sleeping = true
	cube_node.lock_rotation = true
	cube_node.input_ray_pickable = false
	cube_node.collision_layer = 0
	cube_node.collision_mask = 0
	return cube_node


func _remove_embedded_cube_reward_node(card_root: Node3D) -> void:
	if card_root == null:
		return
	var embedded_cube := card_root.get_node_or_null(^"artifact_reward_icon_frame/cube_reward_preview")
	if embedded_cube != null and is_instance_valid(embedded_cube):
		embedded_cube.queue_free()


func _build_cube_reward_description(cube_definition: DiceDefinition) -> String:
	if cube_definition == null:
		return ""
	if not cube_definition.description.is_empty():
		return cube_definition.description
	return "Редкость: %s · Область: %s" % [_format_cube_rarity(cube_definition.rarity), _format_cube_scope(cube_definition.scope)]


func _format_cube_rarity(rarity: int) -> String:
	match rarity:
		DiceDefinition.Rarity.COMMON:
			return "Обычный"
		DiceDefinition.Rarity.UNCOMMON:
			return "Необычный"
		DiceDefinition.Rarity.RARE:
			return "Редкий"
		DiceDefinition.Rarity.UNIQUE:
			return "Уникальный"
	return "Неизвестно"


func _format_cube_scope(scope: int) -> String:
	match scope:
		DiceDefinition.Scope.COMBAT:
			return "Бой"
		DiceDefinition.Scope.GLOBAL_MAP:
			return "Карта"
		DiceDefinition.Scope.REWARD:
			return "Награда"
		DiceDefinition.Scope.MONEY:
			return "Деньги"
		DiceDefinition.Scope.EVENT:
			return "Событие"
	return "Другое"


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
		for scope in [
			DiceDefinition.Scope.COMBAT,
			DiceDefinition.Scope.GLOBAL_MAP,
			DiceDefinition.Scope.REWARD,
			DiceDefinition.Scope.MONEY,
			DiceDefinition.Scope.EVENT,
		]:
			for owned_cube in player.get_runtime_cubes_by_scope(scope):
				if owned_cube != null and _is_unique_cube(owned_cube) and owned_cube.resource_path == selected_cube.resource_path:
					_clear_cube_reward_cards(owner)
					return
	player.grant_runtime_cube(selected_cube)
	print("[Debug][RewardFlow] Игрок выбрал куб: %s (%s)." % [selected_cube.dice_name, _format_cube_scope(selected_cube.scope)])
	_clear_cube_reward_cards(owner)
	_return_to_saved_global_map(owner)


func _update_reward_waiting_state(owner: Node) -> void:
	owner._is_awaiting_ability_reward_selection = not owner._ability_reward_entries.is_empty() or not owner._artifact_reward_entries.is_empty() or not owner._cube_reward_entries.is_empty()


func _return_to_saved_global_map(owner: Node, delay_seconds: float = 0.0) -> void:
	if owner == null:
		return
	if delay_seconds > 0.0:
		await owner.get_tree().create_timer(delay_seconds).timeout
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
