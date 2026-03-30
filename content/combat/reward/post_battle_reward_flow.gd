extends RefCounted
class_name PostBattleRewardFlow

const Dice = preload("res://content/dice/dice.gd")

const POST_BATTLE_REWARD_DICE_SIZE_MULTIPLIER := Vector3(4.0, 4.0, 4.0)
const POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER := 1.0
const POST_BATTLE_REWARD_DICE_DELAY_SECONDS := 1.0
const REWARD_CARD_NEW_FACE_ID := &"card_+"
const REWARD_CARD_UP_FACE_ID := &"card_up"
const ABILITY_REWARD_OPTIONS_COUNT := 3
const ABILITY_REWARD_CARD_MIN_SPACING_X := 3.2
const ABILITY_REWARD_CARD_GAP_X := 0.35
const ABILITY_DEFINITIONS_DIRECTORY := "res://content/abilities/definitions"
const RARITY_COMMON_WEIGHT := 50.0
const RARITY_UNCOMMON_WEIGHT := 30.0
const RARITY_RARE_WEIGHT := 20.0
const RARITY_UNIQUE_WEIGHT := 10.0
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
	var reward_cube = player.runtime_reward_cube
	var money_cube = player.runtime_money_cube
	if reward_cube == null and money_cube == null:
		return
	var requests: Array[DiceThrowRequest] = []
	if reward_cube != null:
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


func _render_ability_reward_cards(owner: Node, entries: Array[Dictionary]) -> void:
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
		var ability := entries[index].get("ability") as AbilityDefinition
		_apply_reward_card_visual(owner, card_root, ability)
		owner._ability_reward_entries.append({
			"node": card_root,
			"ability": ability,
		})
		if index > 0:
			owner._generated_ability_reward_nodes.append(card_root)


func _apply_reward_card_visual(owner: Node, card_root: Node3D, ability: AbilityDefinition) -> void:
	if card_root == null:
		return
	var icon_mesh := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if icon_mesh != null and ability != null and ability.icon != null:
		owner._apply_texture_to_mesh(icon_mesh, ability.icon)
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = ability.display_name if ability != null else ""
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = ability.description if ability != null else ""


func _clear_ability_reward_cards(owner: Node) -> void:
	for generated_node in owner._generated_ability_reward_nodes:
		if generated_node != null and is_instance_valid(generated_node):
			generated_node.queue_free()
	owner._generated_ability_reward_nodes.clear()
	owner._ability_reward_entries.clear()
	owner._is_awaiting_ability_reward_selection = false
	if owner._ability_reward_template != null:
		owner._ability_reward_template.visible = false


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


func _return_to_saved_global_map(owner: Node) -> void:
	if owner == null:
		return
	var tree := owner.get_tree()
	if tree == null:
		return
	var result := tree.change_scene_to_file(GLOBAL_MAP_SCENE_PATH)
	if result != OK:
		push_warning("Failed to open global map scene: %s" % GLOBAL_MAP_SCENE_PATH)
