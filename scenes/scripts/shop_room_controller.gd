extends Node3D
class_name ShopRoomController

const BattleTargetingService = preload("res://content/combat/presentation/battle_targeting_service.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const Player = preload("res://content/entities/player.gd")
const AbilityDefinition = preload("res://content/abilities/resources/ability_definition.gd")
const ArtifactDefinition = preload("res://content/artifacts/resources/artifact_definition.gd")
const DiceDefinition = preload("res://content/dice/resources/dice_definition.gd")
const Dice = preload("res://content/dice/dice.gd")

const GLOBAL_MAP_SCENE_PATH := "res://scenes/global_map_room.tscn"
const ABILITY_DEFINITIONS_DIRECTORY := "res://content/abilities/definitions"
const ARTIFACT_DEFINITIONS_DIRECTORY := "res://content/artifacts/definitions"
const DICE_DEFINITIONS_DIRECTORY := "res://content/dice/definitions"
const BASE_CUBE_SCENE_PATH := "res://content/resources/base_cube.tscn"

const ABILITY_SLOT_COUNT := 4
const ARTIFACT_SLOT_COUNT := 2
const DICE_SLOT_COUNT := 2

const UPGRADE_SERVICE_PRICE := 15
const REMOVE_SERVICE_PRICE := 10

const ABILITY_RARITY_WEIGHTS := [50.0, 30.0, 20.0, 10.0]
const ARTIFACT_RARITY_WEIGHTS := [50.0, 25.0, 15.0, 10.0]
const DICE_RARITY_WEIGHTS := [50.0, 25.0, 15.0, 10.0]

const ABILITY_PRICE_MULTIPLIER_MIN := 3
const ABILITY_PRICE_MULTIPLIER_MAX := 8
const ARTIFACT_PRICE_MULTIPLIER_MIN := 6
const ARTIFACT_PRICE_MULTIPLIER_MAX := 11
const DICE_PRICE_MULTIPLIER_MIN := 5
const DICE_PRICE_MULTIPLIER_MAX := 7

const CUBE_REWARD_VISUAL_ROTATION_DEGREES := Vector3(45.0, 10.0, -120.0)
const CUBE_REWARD_VISUAL_POSITION_OFFSET := Vector3(0.0, 0.3, 0.0)
const CUBE_REWARD_VISUAL_SCALE_MULTIPLIER := Vector3(1.5, 1.5, 1.5)

const OFFER_KIND_ABILITY := &"ability"
const OFFER_KIND_ARTIFACT := &"artifact"
const OFFER_KIND_DICE := &"dice"
const OFFER_KIND_UPGRADE := &"upgrade_service"
const OFFER_KIND_REMOVE := &"remove_service"

const SHOP_MODE_BROWSE := &"browse"
const SHOP_MODE_SELECT_UPGRADE := &"select_upgrade"
const SHOP_MODE_SELECT_REMOVE := &"select_remove"

@onready var _camera: Camera3D = $background/Camera3D
@onready var _ability_template: Node3D = $ability_reward
@onready var _card_up_icon: MeshInstance3D = $card_up_icon
@onready var _card_remove_icon: MeshInstance3D = $"card_-_icon"

var _targeting := BattleTargetingService.new()
var _rng := RandomNumberGenerator.new()
var _player: Player
var _shop_mode: StringName = SHOP_MODE_BROWSE

var _ability_offers: Array[Dictionary] = []
var _artifact_offers: Array[Dictionary] = []
var _dice_offers: Array[Dictionary] = []
var _upgrade_offer: Dictionary = {}
var _remove_offer: Dictionary = {}
var _pending_service_offer: Dictionary = {}
var _selection_entries: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	_player = GlobalMapRuntimeState.load_runtime_player()
	if _player == null:
		push_warning("ShopRoomController: runtime player is null.")
	_setup_exit_button()
	_prepare_shop()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _shop_mode == SHOP_MODE_SELECT_UPGRADE:
		_try_pick_upgrade_option(mouse_button.position)
		return
	if _shop_mode == SHOP_MODE_SELECT_REMOVE:
		_try_pick_remove_option(mouse_button.position)
		return
	_try_pick_shop_offer(mouse_button.position)


func _prepare_shop() -> void:
	if _ability_template == null:
		return
	_ability_template.visible = false
	_setup_service_prices()
	_clear_dynamic_offers()
	_build_top_ability_offers()
	_build_bottom_offers()
	_upgrade_offer = {
		"kind": OFFER_KIND_UPGRADE,
		"price": UPGRADE_SERVICE_PRICE,
		"is_sold": false,
		"mesh": _card_up_icon,
	}
	_remove_offer = {
		"kind": OFFER_KIND_REMOVE,
		"price": REMOVE_SERVICE_PRICE,
		"is_sold": false,
		"mesh": _card_remove_icon,
	}


func _setup_exit_button() -> void:
	var layer := CanvasLayer.new()
	layer.name = "shop_ui"
	add_child(layer)
	var button := Button.new()
	button.text = "Покинуть магазин"
	button.position = Vector2(16.0, 16.0)
	button.size = Vector2(220.0, 40.0)
	button.pressed.connect(_open_global_map)
	layer.add_child(button)


func _setup_service_prices() -> void:
	_apply_price_ui_to_service_icon(_card_up_icon, UPGRADE_SERVICE_PRICE)
	_apply_price_ui_to_service_icon(_card_remove_icon, REMOVE_SERVICE_PRICE)


func _build_top_ability_offers() -> void:
	var base_position := _ability_template.transform.origin
	var right_anchor_x := _card_up_icon.transform.origin.x
	var spacing_x := (right_anchor_x - base_position.x) / float(ABILITY_SLOT_COUNT)
	var ability_pool := _load_player_reward_abilities()
	var owned_ability_ids := _collect_owned_ability_ids(_player)
	var offered_ability_ids := {}
	for index in ABILITY_SLOT_COUNT:
		var rolled_rarity := _roll_weighted_rarity(ABILITY_RARITY_WEIGHTS)
		var ability := _pick_ability_by_rarity_with_fallback(ability_pool, rolled_rarity, owned_ability_ids, offered_ability_ids)
		if ability == null:
			continue
		offered_ability_ids[ability.ability_id] = true
		var card := _create_shop_card(base_position + Vector3(spacing_x * index, 0.0, 0.0))
		_apply_ability_visual(card, ability)
		var price := _build_ability_price(ability.rarity)
		_apply_price_ui_to_card(card, price)
		_ability_offers.append({
			"kind": OFFER_KIND_ABILITY,
			"price": price,
			"ability": ability,
			"node": card,
			"is_sold": false,
		})


func _build_bottom_offers() -> void:
	if _ability_offers.is_empty():
		return
	var first_row_z := (_ability_offers[0].get("node") as Node3D).transform.origin.z
	var second_row_z := first_row_z + 4.0
	var slot_x_positions: Array[float] = []
	for offer in _ability_offers:
		var node := offer.get("node") as Node3D
		if node != null:
			slot_x_positions.append(node.transform.origin.x)
	if slot_x_positions.size() < 4:
		return

	var artifacts := _build_artifact_shop_options(ARTIFACT_SLOT_COUNT)
	for index in artifacts.size():
		var artifact := artifacts[index]
		if artifact == null:
			continue
		var card := _create_shop_card(Vector3(slot_x_positions[index], _ability_template.transform.origin.y, second_row_z))
		_apply_artifact_visual(card, artifact)
		var price := _build_artifact_price(_artifact_rarity_to_int(artifact.rarity))
		_apply_price_ui_to_card(card, price)
		_artifact_offers.append({
			"kind": OFFER_KIND_ARTIFACT,
			"price": price,
			"artifact": artifact,
			"node": card,
			"is_sold": false,
		})

	var cubes := _build_cube_shop_options(DICE_SLOT_COUNT)
	for index in cubes.size():
		var cube := cubes[index]
		if cube == null:
			continue
		var x_index := index + ARTIFACT_SLOT_COUNT
		var card := _create_shop_card(Vector3(slot_x_positions[x_index], _ability_template.transform.origin.y, second_row_z))
		_apply_cube_visual(card, cube)
		var price := _build_cube_price(cube.rarity)
		_apply_price_ui_to_card(card, price)
		_dice_offers.append({
			"kind": OFFER_KIND_DICE,
			"price": price,
			"cube": cube,
			"node": card,
			"is_sold": false,
		})


func _try_pick_shop_offer(screen_point: Vector2) -> void:
	for index in range(_ability_offers.size() - 1, -1, -1):
		if _offer_hit(_ability_offers[index], screen_point):
			_try_purchase_offer(_ability_offers, index)
			return
	for index in range(_artifact_offers.size() - 1, -1, -1):
		if _offer_hit(_artifact_offers[index], screen_point):
			_try_purchase_offer(_artifact_offers, index)
			return
	for index in range(_dice_offers.size() - 1, -1, -1):
		if _offer_hit(_dice_offers[index], screen_point):
			_try_purchase_offer(_dice_offers, index)
			return
	if _targeting.screen_point_hits_mesh(_card_up_icon, screen_point, _camera):
		_try_purchase_service_offer(true)
		return
	if _targeting.screen_point_hits_mesh(_card_remove_icon, screen_point, _camera):
		_try_purchase_service_offer(false)


func _try_purchase_offer(offers: Array[Dictionary], index: int) -> void:
	if index < 0 or index >= offers.size():
		return
	var offer := offers[index]
	if bool(offer.get("is_sold", false)):
		return
	var price := int(offer.get("price", 0))
	if _player == null or not _player.spend_coins(price):
		return
	var kind := offer.get("kind", &"") as StringName
	if kind == OFFER_KIND_ABILITY:
		var ability := offer.get("ability") as AbilityDefinition
		if ability != null:
			_player.ability_loadout.append(ability)
	elif kind == OFFER_KIND_ARTIFACT:
		var artifact := offer.get("artifact") as ArtifactDefinition
		if artifact != null:
			_player.grant_artifact(artifact)
	elif kind == OFFER_KIND_DICE:
		var cube := offer.get("cube") as DiceDefinition
		if cube != null:
			_player.grant_runtime_cube(cube)
	offer["is_sold"] = true
	offers[index] = offer
	_mark_offer_as_sold(offer)
	GlobalMapRuntimeState.save_runtime_player(_player)


func _try_purchase_service_offer(is_upgrade: bool) -> void:
	var offer := _upgrade_offer if is_upgrade else _remove_offer
	if offer.is_empty() or bool(offer.get("is_sold", false)):
		return
	if _player == null:
		return
	var service_entries := _build_upgrade_selection_entries() if is_upgrade else _build_remove_selection_entries()
	if service_entries.is_empty():
		return
	var price := int(offer.get("price", 0))
	if not _player.spend_coins(price):
		return
	_pending_service_offer = offer
	_selection_entries = service_entries
	_shop_mode = SHOP_MODE_SELECT_UPGRADE if is_upgrade else SHOP_MODE_SELECT_REMOVE
	_render_selection_entries(service_entries)


func _try_pick_upgrade_option(screen_point: Vector2) -> void:
	for index in range(_selection_entries.size() - 1, -1, -1):
		var entry := _selection_entries[index]
		var card := entry.get("node") as Node3D
		if card == null:
			continue
		var frame := card.get_node_or_null(^"ability_frame_base") as MeshInstance3D
		if not _targeting.screen_point_hits_mesh(frame, screen_point, _camera):
			continue
		var replace_index := int(entry.get("replace_index", -1))
		var next_ability := entry.get("ability") as AbilityDefinition
		if replace_index >= 0 and replace_index < _player.ability_loadout.size() and next_ability != null:
			_player.ability_loadout[replace_index] = next_ability
		_complete_service_purchase(true)
		return


func _try_pick_remove_option(screen_point: Vector2) -> void:
	for index in range(_selection_entries.size() - 1, -1, -1):
		var entry := _selection_entries[index]
		var card := entry.get("node") as Node3D
		if card == null:
			continue
		var frame := card.get_node_or_null(^"ability_frame_base") as MeshInstance3D
		if not _targeting.screen_point_hits_mesh(frame, screen_point, _camera):
			continue
		var remove_index := int(entry.get("remove_index", -1))
		if remove_index >= 0 and remove_index < _player.ability_loadout.size():
			_player.ability_loadout.remove_at(remove_index)
		_complete_service_purchase(false)
		return


func _complete_service_purchase(is_upgrade: bool) -> void:
	var offer := _pending_service_offer
	offer["is_sold"] = true
	if is_upgrade:
		_upgrade_offer = offer
	else:
		_remove_offer = offer
	_mark_offer_as_sold(offer)
	_clear_selection_cards()
	_shop_mode = SHOP_MODE_BROWSE
	_pending_service_offer = {}
	_selection_entries.clear()
	GlobalMapRuntimeState.save_runtime_player(_player)


func _offer_hit(offer: Dictionary, screen_point: Vector2) -> bool:
	if bool(offer.get("is_sold", false)):
		return false
	var node := offer.get("node") as Node3D
	if node == null:
		return false
	var frame := node.get_node_or_null(^"ability_frame_base") as MeshInstance3D
	return _targeting.screen_point_hits_mesh(frame, screen_point, _camera)


func _create_shop_card(world_position: Vector3) -> Node3D:
	var card := _ability_template.duplicate() as Node3D
	add_child(card)
	card.visible = true
	var transform_copy := _ability_template.transform
	transform_copy.origin = world_position
	card.transform = transform_copy
	return card


func _apply_ability_visual(card_root: Node3D, ability: AbilityDefinition) -> void:
	var icon_mesh := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if icon_mesh != null:
		icon_mesh.visible = true
		_apply_texture_to_mesh(icon_mesh, ability.icon)
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = ability.display_name
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = ability.description


func _apply_artifact_visual(card_root: Node3D, artifact: ArtifactDefinition) -> void:
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = artifact.display_name
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = artifact.description
	var icon_mesh := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if icon_mesh != null:
		icon_mesh.visible = true
		_apply_texture_to_mesh(icon_mesh, artifact.sprite)


func _apply_cube_visual(card_root: Node3D, cube_definition: DiceDefinition) -> void:
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = cube_definition.display_name
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = cube_definition.description
	var icon_mesh := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if icon_mesh != null:
		icon_mesh.visible = false
	var cube_preview := _build_cube_preview(cube_definition)
	if cube_preview != null:
		cube_preview.name = "cube_reward_preview"
		card_root.add_child(cube_preview)
		cube_preview.position = Vector3(0.0, 0.02, -0.32)


func _build_cube_preview(cube_definition: DiceDefinition) -> Dice:
	var scene := load(BASE_CUBE_SCENE_PATH) as PackedScene
	if scene == null:
		return null
	var cube_node := scene.instantiate() as Dice
	if cube_node == null:
		return null
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


func _apply_price_ui_to_card(card: Node3D, price: int) -> void:
	var price_root := card.get_node_or_null(^"price_icon_ability") as MeshInstance3D
	if price_root == null:
		return
	var label := _find_or_create_price_label(price_root)
	if label != null:
		label.text = str(price)


func _apply_price_ui_to_service_icon(icon: MeshInstance3D, price: int) -> void:
	if icon == null:
		return
	var price_root := icon.get_child(0) as MeshInstance3D
	if price_root == null:
		return
	if price_root.get_child_count() == 0:
		var coin := MeshInstance3D.new()
		coin.mesh = PlaneMesh.new()
		coin.transform = Transform3D(Basis().scaled(Vector3(0.28, 1.0, 0.85)), Vector3(-0.6, 0.01, 0.0))
		var coin_material := StandardMaterial3D.new()
		coin_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		coin_material.albedo_texture = load("res://assets/ui/coin.png")
		coin.material_override = coin_material
		price_root.add_child(coin)
	var label := _find_or_create_price_label(price_root)
	if label != null:
		label.text = str(price)


func _find_or_create_price_label(price_root: MeshInstance3D) -> Label3D:
	for child in price_root.get_children():
		if child is Label3D:
			return child as Label3D
	var label := Label3D.new()
	label.transform = Transform3D(Basis.IDENTITY, Vector3(0.22, 0.07, -0.02))
	label.pixel_size = 0.01
	label.modulate = Color(0.97, 1.0, 0.07, 1.0)
	label.font_size = 100
	label.outline_size = 30
	label.outline_modulate = Color(0.66, 0.29, 0.15, 1.0)
	price_root.add_child(label)
	return label


func _mark_offer_as_sold(offer: Dictionary) -> void:
	var node := offer.get("node") as Node3D
	if node != null:
		node.visible = false
	var mesh := offer.get("mesh") as MeshInstance3D
	if mesh != null:
		mesh.visible = false


func _build_upgrade_selection_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _player == null:
		return result
	var ability_catalog := _load_ability_catalog()
	var upgradable_entries: Array[Dictionary] = []
	for ability_index in range(_player.ability_loadout.size()):
		var base_ability := _player.ability_loadout[ability_index] as AbilityDefinition
		if base_ability == null:
			continue
		var upgrade_options := _resolve_follow_up_abilities(base_ability, ability_catalog)
		if upgrade_options.is_empty():
			continue
		upgradable_entries.append({"replace_index": ability_index, "options": upgrade_options})
	if upgradable_entries.is_empty() and not _player.ability_loadout.is_empty():
		var random_index := _rng.randi_range(0, _player.ability_loadout.size() - 1)
		var selected := _player.ability_loadout[random_index] as AbilityDefinition
		var parallel_options := _resolve_parallel_upgrade_options(selected, ability_catalog)
		for option in parallel_options:
			var typed_option := option as AbilityDefinition
			if typed_option == null:
				continue
			result.append({"ability": typed_option, "replace_index": random_index})
		return result
	if upgradable_entries.is_empty():
		return result
	var selected_entry := upgradable_entries[_rng.randi_range(0, upgradable_entries.size() - 1)]
	for option in selected_entry.get("options", []):
		var typed_option := option as AbilityDefinition
		if typed_option == null:
			continue
		result.append({"ability": typed_option, "replace_index": int(selected_entry.get("replace_index", -1))})
	return result


func _build_remove_selection_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _player == null:
		return result
	for index in range(_player.ability_loadout.size()):
		var ability := _player.ability_loadout[index] as AbilityDefinition
		if ability == null:
			continue
		result.append({"ability": ability, "remove_index": index})
	return result


func _render_selection_entries(entries: Array[Dictionary]) -> void:
	_clear_selection_cards()
	if _ability_offers.is_empty():
		return
	var spacing := 3.0
	var center := Vector3(0.0, _ability_template.transform.origin.y, _ability_template.transform.origin.z)
	var start_x := center.x - ((entries.size() - 1) * spacing * 0.5)
	for index in entries.size():
		var ability := entries[index].get("ability") as AbilityDefinition
		if ability == null:
			continue
		var card := _create_shop_card(Vector3(start_x + spacing * index, center.y, center.z))
		_apply_ability_visual(card, ability)
		_apply_price_ui_to_card(card, 0)
		var entry := entries[index]
		entry["node"] = card
		_selection_entries.append(entry)


func _clear_selection_cards() -> void:
	for entry in _selection_entries:
		var node := entry.get("node") as Node3D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_selection_entries.clear()


func _clear_dynamic_offers() -> void:
	for offers in [_ability_offers, _artifact_offers, _dice_offers]:
		for offer in offers:
			var node := offer.get("node") as Node3D
			if node != null and is_instance_valid(node):
				node.queue_free()
	_ability_offers.clear()
	_artifact_offers.clear()
	_dice_offers.clear()


func _load_player_reward_abilities() -> Array[AbilityDefinition]:
	var abilities: Array[AbilityDefinition] = []
	for ability in _load_all_abilities_from_directory():
		if ability.owner_scope != AbilityDefinition.OwnerScope.PLAYER and ability.owner_scope != AbilityDefinition.OwnerScope.ANY:
			continue
		if ability.upgrade_level > 0:
			continue
		abilities.append(ability)
	return abilities


func _load_all_abilities_from_directory() -> Array[AbilityDefinition]:
	var abilities: Array[AbilityDefinition] = []
	var dir := DirAccess.open(ABILITY_DEFINITIONS_DIRECTORY)
	if dir == null:
		return abilities
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var ability := ResourceLoader.load("%s/%s" % [ABILITY_DEFINITIONS_DIRECTORY, file_name]) as AbilityDefinition
		if ability != null:
			abilities.append(ability)
	dir.list_dir_end()
	return abilities


func _load_artifact_definitions() -> Array[ArtifactDefinition]:
	var artifacts: Array[ArtifactDefinition] = []
	var dir := DirAccess.open(ARTIFACT_DEFINITIONS_DIRECTORY)
	if dir == null:
		return artifacts
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var artifact := ResourceLoader.load("%s/%s" % [ARTIFACT_DEFINITIONS_DIRECTORY, file_name]) as ArtifactDefinition
		if artifact != null and artifact.is_valid_definition():
			artifacts.append(artifact)
	dir.list_dir_end()
	return artifacts


func _load_rewardable_cube_definitions() -> Array[DiceDefinition]:
	var cubes: Array[DiceDefinition] = []
	var dir := DirAccess.open(DICE_DEFINITIONS_DIRECTORY)
	if dir == null:
		return cubes
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var cube := ResourceLoader.load("%s/%s" % [DICE_DEFINITIONS_DIRECTORY, file_name]) as DiceDefinition
		if cube == null or cube.scope == DiceDefinition.Scope.SYSTEM:
			continue
		cubes.append(cube)
	dir.list_dir_end()
	return cubes


func _load_ability_catalog() -> Dictionary:
	var catalog := {}
	for ability in _load_all_abilities_from_directory():
		catalog[ability.resource_path] = ability
	return catalog


func _collect_owned_ability_ids(player: Player) -> Dictionary:
	var owned := {}
	if player == null:
		return owned
	for ability in player.ability_loadout:
		if ability != null:
			owned[ability.ability_id] = true
	return owned


func _build_artifact_shop_options(count: int) -> Array[ArtifactDefinition]:
	var generated: Array[ArtifactDefinition] = []
	var artifacts := _load_artifact_definitions()
	if artifacts.is_empty():
		return generated
	var blocked := {}
	for _index in count:
		var rarity_index := _roll_weighted_rarity(ARTIFACT_RARITY_WEIGHTS)
		var picked := _pick_artifact_by_rarity_with_fallback(artifacts, _int_to_artifact_rarity(rarity_index), blocked)
		if picked == null:
			continue
		blocked[picked.artifact_id] = true
		generated.append(picked)
	return generated


func _build_cube_shop_options(count: int) -> Array[DiceDefinition]:
	var generated: Array[DiceDefinition] = []
	var cubes := _load_rewardable_cube_definitions()
	if cubes.is_empty():
		return generated
	var blocked := {}
	for _index in count:
		var rarity := _roll_weighted_rarity(DICE_RARITY_WEIGHTS)
		var picked := _pick_cube_by_rarity_with_fallback(cubes, rarity, blocked)
		if picked == null:
			continue
		blocked[picked.resource_path] = true
		generated.append(picked)
	return generated


func _roll_weighted_rarity(weights: Array) -> int:
	var total := 0.0
	for value in weights:
		total += value
	var roll := _rng.randf_range(0.0, total)
	for index in range(weights.size()):
		if roll < weights[index]:
			return index
		roll -= weights[index]
	return max(weights.size() - 1, 0)


func _pick_ability_by_rarity_with_fallback(
	abilities: Array[AbilityDefinition],
	start_rarity: int,
	owned_ability_ids: Dictionary,
	offered_ability_ids: Dictionary
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
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return null


func _pick_artifact_by_rarity_with_fallback(
	artifacts: Array[ArtifactDefinition],
	start_rarity: StringName,
	blocked_ids: Dictionary
) -> ArtifactDefinition:
	for rarity in _build_artifact_rarity_fallback_chain(start_rarity):
		var candidates: Array[ArtifactDefinition] = []
		for artifact in artifacts:
			if artifact == null or artifact.rarity != rarity:
				continue
			if blocked_ids.has(artifact.artifact_id):
				continue
			candidates.append(artifact)
		if candidates.is_empty():
			continue
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return null


func _pick_cube_by_rarity_with_fallback(
	cubes: Array[DiceDefinition],
	start_rarity: int,
	blocked_ids: Dictionary
) -> DiceDefinition:
	for rarity in range(start_rarity, DiceDefinition.Rarity.COMMON - 1, -1):
		var candidates: Array[DiceDefinition] = []
		for cube in cubes:
			if cube == null or cube.rarity != rarity:
				continue
			if blocked_ids.has(cube.resource_path):
				continue
			candidates.append(cube)
		if candidates.is_empty():
			continue
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return null


func _build_artifact_rarity_fallback_chain(start_rarity: StringName) -> Array[StringName]:
	var ordered: Array[StringName] = [&"common", &"uncommon", &"rare", &"unique"]
	var start_index := maxi(ordered.find(start_rarity), 0)
	var chain: Array[StringName] = []
	for index in range(start_index, -1, -1):
		chain.append(ordered[index])
	return chain


func _resolve_follow_up_abilities(base_ability: AbilityDefinition, ability_catalog: Dictionary) -> Array[AbilityDefinition]:
	var resolved: Array[AbilityDefinition] = []
	if base_ability == null:
		return resolved
	for follow_up_id in base_ability.follow_up_ability_ids:
		var follow_up := ability_catalog.get(str(follow_up_id), null) as AbilityDefinition
		if follow_up != null:
			resolved.append(follow_up)
	return resolved


func _resolve_parallel_upgrade_options(current_ability: AbilityDefinition, ability_catalog: Dictionary) -> Array[AbilityDefinition]:
	var resolved: Array[AbilityDefinition] = []
	if current_ability == null:
		return resolved
	var base_ability := _find_base_ability_for_family(current_ability, ability_catalog)
	if base_ability != null:
		resolved = _resolve_follow_up_abilities(base_ability, ability_catalog)
	if not _contains_ability_resource(resolved, current_ability.resource_path):
		resolved.append(current_ability)
	return resolved


func _find_base_ability_for_family(ability: AbilityDefinition, ability_catalog: Dictionary) -> AbilityDefinition:
	if ability == null:
		return null
	if ability.upgrade_level <= 0:
		return ability
	for candidate in ability_catalog.values():
		var typed := candidate as AbilityDefinition
		if typed != null and typed.ability_id == ability.ability_id and typed.upgrade_level == 0:
			return typed
	return ability


func _contains_ability_resource(abilities: Array[AbilityDefinition], resource_path: String) -> bool:
	for ability in abilities:
		if ability != null and ability.resource_path == resource_path:
			return true
	return false


func _build_ability_price(rarity: int) -> int:
	return clampi((rarity + 1) * _rng.randi_range(ABILITY_PRICE_MULTIPLIER_MIN, ABILITY_PRICE_MULTIPLIER_MAX), 1, 99)


func _build_artifact_price(rarity: int) -> int:
	return clampi((rarity + 2) * _rng.randi_range(ARTIFACT_PRICE_MULTIPLIER_MIN, ARTIFACT_PRICE_MULTIPLIER_MAX), 1, 99)


func _build_cube_price(rarity: int) -> int:
	return clampi((rarity + 2) * _rng.randi_range(DICE_PRICE_MULTIPLIER_MIN, DICE_PRICE_MULTIPLIER_MAX), 1, 99)


func _artifact_rarity_to_int(rarity: StringName) -> int:
	match rarity:
		&"uncommon":
			return 1
		&"rare":
			return 2
		&"unique":
			return 3
		_:
			return 0


func _int_to_artifact_rarity(index: int) -> StringName:
	match index:
		1:
			return &"uncommon"
		2:
			return &"rare"
		3:
			return &"unique"
		_:
			return &"common"


func _apply_texture_to_mesh(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	if mesh_instance == null or texture == null:
		return
	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		mesh_instance.material_override = material
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture


func _open_global_map() -> void:
	GlobalMapRuntimeState.save_runtime_player(_player)
	var result := get_tree().change_scene_to_file(GLOBAL_MAP_SCENE_PATH)
	if result != OK:
		push_warning("Failed to open global map scene: %s" % GLOBAL_MAP_SCENE_PATH)
