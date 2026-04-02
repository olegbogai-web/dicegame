extends Node3D
class_name ShopRoomController

const PostBattleRewardFlow = preload("res://content/combat/reward/post_battle_reward_flow.gd")
const BattleTargetingService = preload("res://content/combat/presentation/battle_targeting_service.gd")
const BattleSceneViewRenderer = preload("res://content/combat/presentation/battle_scene_view_renderer.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const BattleRoom = preload("res://content/rooms/subclasses/battle_room.gd")

const ABILITY_SLOT_COUNT := 4
const ARTIFACT_SLOT_COUNT := 2
const CUBE_SLOT_COUNT := 2
const CARD_UP_FIXED_PRICE := 15
const CARD_REMOVE_FIXED_PRICE := 10
const SHOP_RARITY_MIN_MULTIPLIER := 3
const SHOP_RARITY_MAX_MULTIPLIER := 8
const SHOP_ARTIFACT_MIN_MULTIPLIER := 6
const SHOP_ARTIFACT_MAX_MULTIPLIER := 11
const SHOP_CUBE_MIN_MULTIPLIER := 5
const SHOP_CUBE_MAX_MULTIPLIER := 7
const ABILITY_ROW_OFFSET_Z := 0.0
const BOTTOM_ROW_OFFSET_Z := 8.2
const PRICE_OFFSET_Y := 0.0
const PRICE_OFFSET_Z := 2.21
const LOW_FUNDS_TINT := Color(0.75, 0.5, 0.5, 1.0)
const AVAILABLE_TINT := Color(1.0, 1.0, 1.0, 1.0)
const MODAL_SELECTION_Y := 5.0
const MODAL_SELECTION_Z := 0.0
const MODAL_OVERLAY_SORTING_OFFSET := 50.0
const MODAL_OVERLAY_RENDER_PRIORITY := 50

@onready var _camera: Camera3D = $background/Camera3D
@onready var _ability_template: Node3D = $ability_reward
@onready var _ability_price_template: MeshInstance3D = $ability_reward/price_icon_ability
@onready var _artifact_reward_template: MeshInstance3D = $artefact_frame_reward
@onready var _sold_template: MeshInstance3D = $ability_reward/sold
@onready var _card_upgrade_mesh: MeshInstance3D = $card_up_icon
@onready var _card_upgrade_sold_template: MeshInstance3D = $card_up_icon/sold
@onready var _card_upgrade_price: MeshInstance3D = $card_up_icon/price_card_up
@onready var _card_remove_mesh: MeshInstance3D = $"card_-_icon"
@onready var _card_remove_sold_template: MeshInstance3D = $"card_-_icon/sold"
@onready var _card_remove_price: MeshInstance3D = $"card_-_icon/price_card_-"
@onready var _leave_button: Button = $ui/leave_shop_button

var _reward_flow := PostBattleRewardFlow.new()
var _targeting := BattleTargetingService.new()
var _renderer := BattleSceneViewRenderer.new()
var _rng := RandomNumberGenerator.new()
var _runtime_player: Player

var _offer_entries: Array[Dictionary] = []
var _ability_reward_rng := RandomNumberGenerator.new()
var _ability_reward_entries: Array[Dictionary] = []
var _generated_ability_reward_nodes: Array[Node3D] = []
var _artifact_reward_entries: Array[Dictionary] = []
var _generated_artifact_reward_nodes: Array[Node3D] = []
var _cube_reward_entries: Array[Dictionary] = []
var _generated_cube_reward_nodes: Array[Node3D] = []
var _is_awaiting_ability_reward_selection := false
var _selection_mode := ""
var _selection_service_entry: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_ability_reward_rng.randomize()
	_runtime_player = _resolve_or_create_runtime_player()
	_setup_fixed_price_badges()
	_generate_shop_inventory()
	_refresh_offers_visual_state()
	if _leave_button != null and not _leave_button.pressed.is_connected(_on_leave_shop_pressed):
		_leave_button.pressed.connect(_on_leave_shop_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _selection_mode == "upgrade" or _selection_mode == "remove":
		get_viewport().set_input_as_handled()
	var picked_offer := _resolve_offer_click(mouse_button.position)
	if picked_offer.is_empty():
		return
	_try_purchase_offer(picked_offer)


func _resolve_offer_click(screen_point: Vector2) -> Dictionary:
	if _selection_mode == "upgrade" or _selection_mode == "remove":
		for index in range(_ability_reward_entries.size() - 1, -1, -1):
			var modal_entry: Dictionary = _ability_reward_entries[index]
			var node := modal_entry.get("node") as Node3D
			if node == null:
				continue
			var frame := node.get_node_or_null(^"ability_frame_base") as MeshInstance3D
			if _screen_point_hits_mesh(frame, screen_point):
				return {
					"offer_type": _selection_mode,
					"selection_entry": modal_entry,
				}
		return {}
	for index in range(_offer_entries.size() - 1, -1, -1):
		var entry: Dictionary = _offer_entries[index]
		if bool(entry.get("is_sold", false)):
			continue
		var hit_mesh := entry.get("hit_mesh") as MeshInstance3D
		if _screen_point_hits_mesh(hit_mesh, screen_point):
			return entry
	return {}


func _try_purchase_offer(entry: Dictionary) -> void:
	if _runtime_player == null:
		return
	var offer_type := str(entry.get("offer_type", ""))
	if offer_type == "upgrade" or offer_type == "remove":
		_resolve_service_selection(entry)
		return
	var price := int(entry.get("price", 0))
	if not _runtime_player.spend_coins(price):
		return
	match offer_type:
		"ability":
			var ability := entry.get("ability") as AbilityDefinition
			if ability != null:
				_runtime_player.grant_ability(ability, _ability_reward_rng)
		"artifact":
			var artifact := entry.get("artifact") as ArtifactDefinition
			if artifact != null:
				_runtime_player.grant_artifact(artifact)
		"cube":
			var cube := entry.get("cube") as DiceDefinition
			if cube != null:
				_runtime_player.grant_runtime_cube(cube)
		"card_upgrade":
			_open_upgrade_modal(entry)
			return
		"card_remove":
			_open_remove_modal(entry)
			return
	entry["is_sold"] = true
	_update_offer_entry(entry)
	_refresh_offers_visual_state()
	GlobalMapRuntimeState.save_runtime_player(_runtime_player)


func _open_upgrade_modal(service_entry: Dictionary) -> void:
	var options := _build_upgrade_modal_entries()
	if options.is_empty():
		_runtime_player.add_coins(int(service_entry.get("price", 0)))
		return
	_selection_mode = "upgrade"
	_selection_service_entry = service_entry
	_render_modal_cards(options)


func _open_remove_modal(service_entry: Dictionary) -> void:
	var options := _build_remove_modal_entries()
	if options.is_empty():
		_runtime_player.add_coins(int(service_entry.get("price", 0)))
		return
	_selection_mode = "remove"
	_selection_service_entry = service_entry
	_render_modal_cards(options)


func _resolve_service_selection(entry: Dictionary) -> void:
	var selection_entry := entry.get("selection_entry", {}) as Dictionary
	if selection_entry.is_empty():
		return
	if _selection_mode == "upgrade":
		var replace_index := int(selection_entry.get("replace_index", -1))
		var ability := selection_entry.get("ability") as AbilityDefinition
		if replace_index >= 0 and replace_index < _runtime_player.ability_loadout.size() and ability != null:
			_runtime_player.ability_loadout[replace_index] = ability
	elif _selection_mode == "remove":
		var remove_index := int(selection_entry.get("remove_index", -1))
		if remove_index >= 0 and remove_index < _runtime_player.ability_loadout.size():
			_runtime_player.ability_loadout.remove_at(remove_index)
	if not _selection_service_entry.is_empty():
		_selection_service_entry["is_sold"] = true
		_update_offer_entry(_selection_service_entry)
	_clear_modal_cards()
	_selection_mode = ""
	_selection_service_entry = {}
	_refresh_offers_visual_state()
	GlobalMapRuntimeState.save_runtime_player(_runtime_player)


func _generate_shop_inventory() -> void:
	_clear_generated_offers()
	_generate_ability_offers()
	_generate_artifact_offers()
	_generate_cube_offers()
	_generate_service_offers()


func _generate_ability_offers() -> void:
	var ability_pool := _reward_flow._load_player_reward_abilities()
	var offered_ids := {}
	var owned_ids := _reward_flow._collect_owned_ability_ids(_runtime_player)
	var spacing := _compute_card_spacing_x()
	var origin := _ability_template.transform.origin
	for slot in ABILITY_SLOT_COUNT:
		var rarity := _reward_flow._roll_reward_rarity(self)
		var picked := _reward_flow._pick_ability_by_rarity_with_fallback(ability_pool, rarity, owned_ids, offered_ids, self)
		if picked == null:
			continue
		offered_ids[picked.ability_id] = true
		var card := _ability_template if slot == 0 else (_ability_template.duplicate() as Node3D)
		if slot > 0:
			add_child(card)
		card.visible = true
		card.transform.origin = origin + Vector3(float(slot) * spacing, 0.0, ABILITY_ROW_OFFSET_Z)
		_apply_ability_visual(card, picked)
		var price := _compute_ability_price(picked.rarity)
		_apply_price_visual(card.get_node_or_null(^"price_icon_ability") as MeshInstance3D, price)
		_offer_entries.append({
			"offer_id": "ability_%d" % slot,
			"offer_type": "ability",
			"ability": picked,
			"price": price,
			"is_sold": false,
			"card": card,
			"hit_mesh": card.get_node_or_null(^"ability_frame_base") as MeshInstance3D,
		})


func _generate_artifact_offers() -> void:
	var artifacts := _reward_flow._load_artifact_definitions()
	var blocked_unique := _reward_flow._collect_owned_unique_artifact_ids(_runtime_player)
	var offered_ids := {}
	var start := _ability_template.transform.origin + Vector3(0.0, 0.0, BOTTOM_ROW_OFFSET_Z)
	var spacing := _compute_card_spacing_x()
	for slot in ARTIFACT_SLOT_COUNT:
		var rarity := _reward_flow._roll_artifact_reward_rarity(self)
		var artifact := _pick_artifact_without_duplicates(artifacts, rarity, blocked_unique, offered_ids)
		if artifact == null:
			continue
		offered_ids[artifact.artifact_id] = true
		if _reward_flow._is_unique_artifact(artifact):
			blocked_unique[artifact.artifact_id] = true
		var card := (_ability_template.duplicate() as Node3D)
		add_child(card)
		card.visible = true
		card.transform.origin = start + Vector3(float(slot) * spacing, 0.0, 0.0)
		_apply_artifact_visual(card, artifact)
		var price := _compute_artifact_price(_artifact_rarity_to_int(artifact.rarity))
		_ensure_price_badge(card)
		_apply_price_visual(card.get_node_or_null(^"price_icon_ability") as MeshInstance3D, price)
		_offer_entries.append({
			"offer_id": "artifact_%d" % slot,
			"offer_type": "artifact",
			"artifact": artifact,
			"price": price,
			"is_sold": false,
			"card": card,
			"hit_mesh": card.get_node_or_null(^"ability_frame_base") as MeshInstance3D,
		})


func _generate_cube_offers() -> void:
	var cubes := _reward_flow._load_rewardable_cube_definitions()
	var blocked_unique := _reward_flow._collect_owned_unique_cube_ids(_runtime_player)
	var offered_ids := {}
	var start := _ability_template.transform.origin + Vector3(_compute_card_spacing_x() * 2.0, 0.0, BOTTOM_ROW_OFFSET_Z)
	var spacing := _compute_card_spacing_x()
	for slot in CUBE_SLOT_COUNT:
		var rarity := _reward_flow._roll_cube_reward_rarity(self)
		var cube := _pick_cube_without_duplicates(cubes, rarity, blocked_unique, offered_ids)
		if cube == null:
			continue
		offered_ids[cube.resource_path] = true
		if _reward_flow._is_unique_cube(cube):
			blocked_unique[cube.resource_path] = true
		var card := (_ability_template.duplicate() as Node3D)
		add_child(card)
		card.visible = true
		card.transform.origin = start + Vector3(float(slot) * spacing, 0.0, 0.0)
		_apply_cube_visual(card, cube)
		var price := _compute_cube_price(cube.rarity)
		_ensure_price_badge(card)
		_apply_price_visual(card.get_node_or_null(^"price_icon_ability") as MeshInstance3D, price)
		_offer_entries.append({
			"offer_id": "cube_%d" % slot,
			"offer_type": "cube",
			"cube": cube,
			"price": price,
			"is_sold": false,
			"card": card,
			"hit_mesh": card.get_node_or_null(^"ability_frame_base") as MeshInstance3D,
		})


func _generate_service_offers() -> void:
	_apply_price_visual(_card_upgrade_price, CARD_UP_FIXED_PRICE)
	_apply_price_visual(_card_remove_price, CARD_REMOVE_FIXED_PRICE)
	_offer_entries.append({
		"offer_id": "service_upgrade",
		"offer_type": "card_upgrade",
		"price": CARD_UP_FIXED_PRICE,
		"is_sold": false,
		"card": _card_upgrade_mesh,
		"hit_mesh": _card_upgrade_mesh,
	})
	_offer_entries.append({
		"offer_id": "service_remove",
		"offer_type": "card_remove",
		"price": CARD_REMOVE_FIXED_PRICE,
		"is_sold": false,
		"card": _card_remove_mesh,
		"hit_mesh": _card_remove_mesh,
	})


func _build_upgrade_modal_entries() -> Array[Dictionary]:
	var player := _runtime_player
	if player == null:
		return []
	var ability_catalog := _reward_flow._load_ability_catalog()
	var upgradable_entries: Array[Dictionary] = []
	for ability_index in range(player.ability_loadout.size()):
		var base_ability := player.ability_loadout[ability_index] as AbilityDefinition
		if base_ability == null:
			continue
		var options := _reward_flow._resolve_follow_up_abilities(base_ability, ability_catalog)
		if options.is_empty():
			continue
		upgradable_entries.append({
			"replace_index": ability_index,
			"options": options,
		})
	if not upgradable_entries.is_empty():
		var picked := upgradable_entries[_ability_reward_rng.randi_range(0, upgradable_entries.size() - 1)]
		var result: Array[Dictionary] = []
		for ability_option in picked.get("options", []):
			var typed := ability_option as AbilityDefinition
			if typed == null:
				continue
			result.append({"ability": typed, "replace_index": int(picked.get("replace_index", -1))})
		return result
	if player.ability_loadout.is_empty():
		return []
	var random_index := _ability_reward_rng.randi_range(0, player.ability_loadout.size() - 1)
	var selected := player.ability_loadout[random_index] as AbilityDefinition
	if selected == null:
		return []
	var parallel := _reward_flow._resolve_parallel_upgrade_options(selected, ability_catalog)
	var fallback: Array[Dictionary] = []
	for ability_option in parallel:
		var typed_option := ability_option as AbilityDefinition
		if typed_option == null:
			continue
		fallback.append({"ability": typed_option, "replace_index": random_index})
	return fallback


func _build_remove_modal_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _runtime_player == null:
		return entries
	for ability_index in range(_runtime_player.ability_loadout.size()):
		var ability := _runtime_player.ability_loadout[ability_index] as AbilityDefinition
		if ability == null:
			continue
		entries.append({
			"ability": ability,
			"remove_index": ability_index,
		})
	return entries


func _render_modal_cards(entries: Array[Dictionary]) -> void:
	_clear_modal_cards()
	if entries.is_empty():
		return
	var spacing := _compute_card_spacing_x()
	var centered_offsets := _build_centered_offsets(entries.size(), spacing)
	for index in range(entries.size()):
		var entry := entries[index]
		var card := (_ability_template.duplicate() as Node3D)
		add_child(card)
		card.visible = true
		card.transform.origin = Vector3(centered_offsets[index], MODAL_SELECTION_Y, MODAL_SELECTION_Z)
		_apply_modal_overlay_order(card)
		_apply_ability_visual(card, entry.get("ability") as AbilityDefinition)
		var price_badge := card.get_node_or_null(^"price_icon_ability") as MeshInstance3D
		if price_badge != null:
			price_badge.visible = false
		entry["node"] = card
		_ability_reward_entries.append(entry)
		_generated_ability_reward_nodes.append(card)
	_is_awaiting_ability_reward_selection = true


func _apply_modal_overlay_order(card: Node3D) -> void:
	if card == null:
		return
	for visual in card.find_children("*", "VisualInstance3D", true, false):
		(visual as VisualInstance3D).sorting_offset = MODAL_OVERLAY_SORTING_OFFSET
	for label in card.find_children("*", "Label3D", true, false):
		(label as Label3D).render_priority = MODAL_OVERLAY_RENDER_PRIORITY


func _clear_modal_cards() -> void:
	for node in _generated_ability_reward_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_generated_ability_reward_nodes.clear()
	_ability_reward_entries.clear()
	_is_awaiting_ability_reward_selection = false


func _refresh_offers_visual_state() -> void:
	for offer in _offer_entries:
		var card := offer.get("card") as Node3D
		var sold_badge := _ensure_sold_badge(card)
		var is_sold := bool(offer.get("is_sold", false))
		if sold_badge != null:
			_configure_sold_badge_transform(offer, sold_badge)
			sold_badge.visible = is_sold
		var hit_mesh := offer.get("hit_mesh") as MeshInstance3D
		if hit_mesh == null:
			continue
		if is_sold:
			_set_mesh_tint(hit_mesh, AVAILABLE_TINT)
			continue
		var price := int(offer.get("price", 0))
		if _runtime_player == null or _runtime_player.current_coins < price:
			_set_mesh_tint(hit_mesh, LOW_FUNDS_TINT)
		else:
			_set_mesh_tint(hit_mesh, AVAILABLE_TINT)


func _update_offer_entry(updated_entry: Dictionary) -> void:
	for index in range(_offer_entries.size()):
		if str(_offer_entries[index].get("offer_id", "")) != str(updated_entry.get("offer_id", "")):
			continue
		_offer_entries[index] = updated_entry
		return


func _clear_generated_offers() -> void:
	for entry in _offer_entries:
		var card := entry.get("card") as Node3D
		if card != null and card != _ability_template and card != _card_upgrade_mesh and card != _card_remove_mesh and is_instance_valid(card):
			card.queue_free()
	_offer_entries.clear()


func _setup_fixed_price_badges() -> void:
	_ensure_price_badge(_ability_template)
	if _card_upgrade_price != null:
		_card_upgrade_price.name = "price_icon_ability"
		_ensure_price_badge_children(_card_upgrade_price)
	if _card_remove_price != null:
		_card_remove_price.name = "price_icon_ability"
		_ensure_price_badge_children(_card_remove_price)


func _ensure_sold_badge(card_root: Node3D) -> MeshInstance3D:
	if card_root == null:
		return null
	var sold_badge := card_root.get_node_or_null(^"sold") as MeshInstance3D
	if sold_badge == null and _sold_template != null:
		sold_badge = _sold_template.duplicate() as MeshInstance3D
		if sold_badge != null:
			sold_badge.name = "sold"
			card_root.add_child(sold_badge)
	if sold_badge != null:
		sold_badge.visible = false
	return sold_badge


func _configure_sold_badge_transform(offer: Dictionary, sold_badge: MeshInstance3D) -> void:
	if sold_badge == null:
		return
	var offer_type := str(offer.get("offer_type", ""))
	if offer_type == "card_upgrade" and _card_upgrade_sold_template != null:
		sold_badge.transform = _card_upgrade_sold_template.transform
	elif offer_type == "card_remove" and _card_remove_sold_template != null:
		sold_badge.transform = _card_remove_sold_template.transform


func _ensure_price_badge(card_root: Node3D) -> void:
	if card_root == null:
		return
	var badge := card_root.get_node_or_null(^"price_icon_ability") as MeshInstance3D
	if badge == null:
		badge = card_root.get_node_or_null(^"price_card_up") as MeshInstance3D
	if badge == null:
		badge = card_root.get_node_or_null(^"price_card_-") as MeshInstance3D
	if badge == null and _ability_price_template != null:
		badge = _ability_price_template.duplicate() as MeshInstance3D
		if badge != null:
			badge.name = "price_icon_ability"
			card_root.add_child(badge)
	if badge == null:
		return
	badge.name = "price_icon_ability"
	badge.visible = true
	badge.transform.origin = Vector3(0.0, PRICE_OFFSET_Y, PRICE_OFFSET_Z)
	_ensure_price_badge_children(badge)


func _ensure_price_badge_children(badge: MeshInstance3D) -> void:
	if badge == null:
		return
	var coin := badge.get_node_or_null(^"coin_icon") as MeshInstance3D
	if coin == null:
		coin = badge.get_node_or_null(^"MeshInstance3D") as MeshInstance3D
		if coin != null:
			coin.name = "coin_icon"
	if coin == null and _ability_price_template != null:
		var template_coin := _ability_price_template.get_node_or_null(^"coin_icon") as MeshInstance3D
		if template_coin == null:
			template_coin = _ability_price_template.get_node_or_null(^"MeshInstance3D") as MeshInstance3D
		if template_coin != null:
			coin = template_coin.duplicate() as MeshInstance3D
			if coin != null:
				coin.name = "coin_icon"
				badge.add_child(coin)
	var price_label := badge.get_node_or_null(^"price") as Label3D
	if price_label == null:
		price_label = badge.get_node_or_null(^"Label3D") as Label3D
		if price_label != null:
			price_label.name = "price"
	if price_label == null and _ability_price_template != null:
		var template_label := _ability_price_template.get_node_or_null(^"price") as Label3D
		if template_label == null:
			template_label = _ability_price_template.get_node_or_null(^"Label3D") as Label3D
		if template_label != null:
			price_label = template_label.duplicate() as Label3D
			if price_label != null:
				price_label.name = "price"
				badge.add_child(price_label)


func _apply_price_visual(price_badge: MeshInstance3D, price: int) -> void:
	if price_badge == null:
		return
	var price_label := price_badge.get_node_or_null(^"price") as Label3D
	if price_label == null:
		price_label = price_badge.get_node_or_null(^"Label3D") as Label3D
	if price_label != null:
		price_label.text = str(clampi(price, 1, 99))


func _apply_ability_visual(card: Node3D, ability: AbilityDefinition) -> void:
	if card == null:
		return
	var title := card.get_node_or_null(^"ability_text") as Label3D
	if title != null:
		title.text = ability.display_name if ability != null else ""
	var description := card.get_node_or_null(^"abilitu_description") as Label3D
	if description != null:
		description.text = ability.description if ability != null else ""
	var icon := card.get_node_or_null(^"ability_icon") as MeshInstance3D
	if icon != null:
		icon.visible = true
		if ability != null and ability.icon != null:
			_apply_texture_to_mesh(icon, ability.icon)


func _apply_artifact_visual(card: Node3D, artifact: ArtifactDefinition) -> void:
	_reward_flow._apply_artifact_reward_visual(self, card, artifact)


func _apply_cube_visual(card: Node3D, cube: DiceDefinition) -> void:
	_reward_flow._apply_cube_reward_visual(self, card, cube)


func _pick_artifact_without_duplicates(artifacts: Array[ArtifactDefinition], rarity: StringName, blocked_unique: Dictionary, offered_ids: Dictionary) -> ArtifactDefinition:
	for fallback in _reward_flow._build_artifact_rarity_fallback_chain(rarity):
		var candidates: Array[ArtifactDefinition] = []
		for artifact in artifacts:
			if artifact == null or artifact.rarity != fallback:
				continue
			if offered_ids.has(artifact.artifact_id):
				continue
			if _reward_flow._is_unique_artifact(artifact) and blocked_unique.has(artifact.artifact_id):
				continue
			candidates.append(artifact)
		if candidates.is_empty():
			continue
		return candidates[_ability_reward_rng.randi_range(0, candidates.size() - 1)]
	return null


func _pick_cube_without_duplicates(cubes: Array[DiceDefinition], rarity: int, blocked_unique: Dictionary, offered_ids: Dictionary) -> DiceDefinition:
	for fallback in range(rarity, DiceDefinition.Rarity.COMMON - 1, -1):
		var candidates: Array[DiceDefinition] = []
		for cube in cubes:
			if cube == null or cube.rarity != fallback:
				continue
			if offered_ids.has(cube.resource_path):
				continue
			if _reward_flow._is_unique_cube(cube) and blocked_unique.has(cube.resource_path):
				continue
			candidates.append(cube)
		if candidates.is_empty():
			continue
		return candidates[_ability_reward_rng.randi_range(0, candidates.size() - 1)]
	return null


func _compute_ability_price(rarity: int) -> int:
	var multiplier := _rng.randi_range(SHOP_RARITY_MIN_MULTIPLIER, SHOP_RARITY_MAX_MULTIPLIER)
	return clampi((rarity + 1) * multiplier, 1, 99)


func _compute_artifact_price(rarity: int) -> int:
	var multiplier := _rng.randi_range(SHOP_ARTIFACT_MIN_MULTIPLIER, SHOP_ARTIFACT_MAX_MULTIPLIER)
	return clampi((rarity + 2) * multiplier, 1, 99)


func _compute_cube_price(rarity: int) -> int:
	var multiplier := _rng.randi_range(SHOP_CUBE_MIN_MULTIPLIER, SHOP_CUBE_MAX_MULTIPLIER)
	return clampi((rarity + 2) * multiplier, 1, 99)


func _artifact_rarity_to_int(rarity: StringName) -> int:
	match rarity:
		&"uncommon":
			return 1
		&"rare":
			return 2
		&"unique":
			return 3
	return 0


func _compute_card_spacing_x() -> float:
	if _ability_template == null:
		return 3.2
	var frame := _ability_template.get_node_or_null(^"ability_frame_base") as MeshInstance3D
	if frame == null or frame.mesh == null:
		return 3.2
	var size := frame.mesh.get_aabb().size
	var scale := frame.global_transform.basis.get_scale()
	var width := size.x * absf(scale.x)
	return maxf(3.2, width + 0.35)


func _build_centered_offsets(count: int, spacing: float) -> Array[float]:
	return _renderer._build_centered_offsets(count, spacing)


func _screen_point_hits_mesh(mesh_instance: MeshInstance3D, screen_point: Vector2) -> bool:
	return _targeting.screen_point_hits_mesh(mesh_instance, screen_point, _camera)


func _apply_texture_to_mesh(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	_renderer._apply_texture_to_mesh(self, mesh_instance, texture)


func _set_mesh_tint(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return
	var material := mesh_instance.material_override
	if material == null:
		material = StandardMaterial3D.new()
	elif material is StandardMaterial3D:
		material = (material as StandardMaterial3D).duplicate()
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_color = color
	mesh_instance.material_override = material


func _resolve_or_create_runtime_player() -> Player:
	var runtime_player := GlobalMapRuntimeState.load_runtime_player()
	if runtime_player != null:
		runtime_player.ensure_runtime_initialized_from_base_stat()
		return runtime_player
	var player := BattleRoom.build_default_player()
	GlobalMapRuntimeState.save_runtime_player(player)
	return player


func _on_leave_shop_pressed() -> void:
	GlobalMapRuntimeState.save_runtime_player(_runtime_player)
	var map_scene := GlobalMapRuntimeState.load_map_scene_path()
	if map_scene.is_empty():
		map_scene = "res://scenes/global_map_room.tscn"
	get_tree().change_scene_to_file(map_scene)
