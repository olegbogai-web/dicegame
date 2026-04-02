extends Node3D
class_name ShopRoomController

const AbilityDefinition = preload("res://content/abilities/resources/ability_definition.gd")
const ArtifactDefinition = preload("res://content/artifacts/resources/artifact_definition.gd")
const DiceDefinition = preload("res://content/dice/resources/dice_definition.gd")
const Dice = preload("res://content/dice/dice.gd")
const Player = preload("res://content/entities/player.gd")
const BattleTargetingService = preload("res://content/combat/presentation/battle_targeting_service.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const MoneyUi = preload("res://ui/scripts/money_ui.gd")

const GLOBAL_MAP_SCENE_PATH := "res://scenes/global_map_room.tscn"
const ABILITY_DEFINITIONS_DIRECTORY := "res://content/abilities/definitions"
const ARTIFACT_DEFINITIONS_DIRECTORY := "res://content/artifacts/definitions"
const DICE_DEFINITIONS_DIRECTORY := "res://content/dice/definitions"
const BASE_CUBE_SCENE_PATH := "res://content/resources/base_cube.tscn"

const ABILITY_COUNT := 4
const ARTIFACT_COUNT := 2
const CUBE_COUNT := 2
const UPGRADE_PRICE := 15
const REMOVE_PRICE := 10

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

const ABILITY_PRICE_MULT_MIN := 3
const ABILITY_PRICE_MULT_MAX := 8
const ARTIFACT_PRICE_MULT_MIN := 6
const ARTIFACT_PRICE_MULT_MAX := 11
const CUBE_PRICE_MULT_MIN := 5
const CUBE_PRICE_MULT_MAX := 7

const OFFER_STATUS_SOLD := "Куплено"

@onready var _camera: Camera3D = $background/Camera3D
@onready var _ability_template: Node3D = $ability_reward
@onready var _price_template: MeshInstance3D = $ability_reward/price_icon_ability
@onready var _artifact_icon_template: MeshInstance3D = $artefact_frame_reward
@onready var _money_ui: MoneyUi = $money_ui
@onready var _upgrade_icon: MeshInstance3D = $card_up_icon
@onready var _remove_icon: MeshInstance3D = $"card_-_icon"
@onready var _upgrade_price_root: Node3D = $card_up_icon/price_card_up
@onready var _remove_price_root: Node3D = $"card_-_icon/price_card_-"
@onready var _leave_button: Button = $UI/LeaveShopButton

var _targeting := BattleTargetingService.new()
var _rng := RandomNumberGenerator.new()
var _player: Player
var _offers: Array[Dictionary] = []
var _ability_catalog: Dictionary = {}
var _temporary_nodes: Array[Node] = []


func _ready() -> void:
	_rng.randomize()
	_player = GlobalMapRuntimeState.load_runtime_player()
	if _camera != null:
		_camera.current = true
	if _leave_button != null and not _leave_button.pressed.is_connected(_on_leave_shop_pressed):
		_leave_button.pressed.connect(_on_leave_shop_pressed)
	if _money_ui != null and _player != null:
		_money_ui.bind_player(_player)
	_prepare_templates()
	_build_shop_offers()
	_render_offers()


func _prepare_templates() -> void:
	if _ability_template != null:
		_ability_template.visible = false
	if _artifact_icon_template != null:
		_artifact_icon_template.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_try_purchase(mouse_button.position)


func _try_purchase(screen_point: Vector2) -> void:
	for index in range(_offers.size() - 1, -1, -1):
		var offer := _offers[index]
		if bool(offer.get("sold", false)):
			continue
		var clickable := offer.get("clickable") as MeshInstance3D
		if not _targeting.screen_point_hits_mesh(clickable, screen_point, _camera):
			continue
		_process_offer_purchase(index)
		return


func _process_offer_purchase(offer_index: int) -> void:
	if _player == null or offer_index < 0 or offer_index >= _offers.size():
		return
	var offer := _offers[offer_index]
	var offer_type := String(offer.get("type", ""))
	var upgrade_entries: Array[Dictionary] = []
	if offer_type == "upgrade_service":
		upgrade_entries = _build_upgrade_entries()
		if upgrade_entries.is_empty():
			return
	if offer_type == "remove_service" and _player.ability_loadout.is_empty():
		return
	var price := int(offer.get("price", 0))
	if not _player.spend_coins(price):
		return
	match offer_type:
		"ability":
			var ability := offer.get("ability") as AbilityDefinition
			if ability != null:
				_player.ability_loadout.append(ability)
		"artifact":
			var artifact := offer.get("artifact") as ArtifactDefinition
			if artifact != null:
				_player.grant_artifact(artifact)
		"cube":
			var cube := offer.get("cube") as DiceDefinition
			if cube != null:
				_player.grant_runtime_cube(cube)
		"upgrade_service":
			_show_runtime_choice_dialog("Улучшение карты", upgrade_entries, _on_upgrade_selected)
		"remove_service":
			_offer_remove_choice()
	offer["sold"] = true
	_offers[offer_index] = offer
	_update_offer_visual(offer)


func _offer_remove_choice() -> void:
	if _player == null or _player.ability_loadout.is_empty():
		return
	var entries: Array[Dictionary] = []
	for index in _player.ability_loadout.size():
		var ability := _player.ability_loadout[index] as AbilityDefinition
		if ability == null:
			continue
		entries.append({
			"label": ability.display_name,
			"ability_index": index,
		})
	_show_runtime_choice_dialog("Удаление карты", entries, _on_remove_selected)


func _on_upgrade_selected(entry: Dictionary) -> void:
	if _player == null:
		return
	var ability := entry.get("ability") as AbilityDefinition
	var replace_index := int(entry.get("replace_index", -1))
	if ability == null or replace_index < 0 or replace_index >= _player.ability_loadout.size():
		return
	_player.ability_loadout[replace_index] = ability


func _on_remove_selected(entry: Dictionary) -> void:
	if _player == null:
		return
	var ability_index := int(entry.get("ability_index", -1))
	_player.remove_runtime_ability_at(ability_index)


func _show_runtime_choice_dialog(title: String, entries: Array[Dictionary], callback: Callable) -> void:
	if entries.is_empty() or callback.is_null():
		return
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = "Выберите вариант"
	var container := VBoxContainer.new()
	for entry in entries:
		var selected_entry: Dictionary = entry
		var button := Button.new()
		button.text = String(selected_entry.get("label", "Вариант"))
		button.pressed.connect(func() -> void:
			callback.call(selected_entry)
			dialog.hide()
			dialog.queue_free()
		)
		container.add_child(button)
	dialog.add_child(container)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 420))


func _build_shop_offers() -> void:
	_ability_catalog = _load_ability_catalog()
	_offers.clear()
	var owned_ability_ids := _collect_owned_ability_ids()
	var offered_ability_ids := {}
	for _ability_slot in ABILITY_COUNT:
		var rolled_rarity := _roll_ability_rarity()
		var ability := _pick_ability_by_rarity_with_fallback(rolled_rarity, owned_ability_ids, offered_ability_ids)
		if ability == null:
			continue
		offered_ability_ids[ability.ability_id] = true
		_offers.append({
			"type": "ability",
			"ability": ability,
			"price": _calculate_ability_price(ability.rarity),
			"rarity": ability.rarity,
			"sold": false,
		})

	var blocked_artifacts := {}
	for _artifact_slot in ARTIFACT_COUNT:
		var rolled_artifact_rarity := _roll_artifact_rarity()
		var artifact := _pick_artifact_by_rarity_with_fallback(rolled_artifact_rarity, blocked_artifacts)
		if artifact == null:
			continue
		blocked_artifacts[artifact.artifact_id] = true
		_offers.append({
			"type": "artifact",
			"artifact": artifact,
			"price": _calculate_artifact_price(_rarity_name_to_level(artifact.rarity)),
			"rarity": artifact.rarity,
			"sold": false,
		})

	var blocked_cubes := {}
	for _cube_slot in CUBE_COUNT:
		var rolled_cube_rarity := _roll_cube_rarity()
		var cube := _pick_cube_by_rarity_with_fallback(rolled_cube_rarity, blocked_cubes)
		if cube == null:
			continue
		blocked_cubes[cube.resource_path] = true
		_offers.append({
			"type": "cube",
			"cube": cube,
			"price": _calculate_cube_price(cube.rarity),
			"rarity": cube.rarity,
			"sold": false,
		})

	_offers.append({
		"type": "upgrade_service",
		"price": UPGRADE_PRICE,
		"clickable": _upgrade_icon,
		"price_root": _upgrade_price_root,
		"sold": false,
	})
	_offers.append({
		"type": "remove_service",
		"price": REMOVE_PRICE,
		"clickable": _remove_icon,
		"price_root": _remove_price_root,
		"sold": false,
	})


func _render_offers() -> void:
	_clear_generated_nodes()
	if _ability_template == null:
		return
	var template_origin := _ability_template.transform.origin
	var spacing := (_upgrade_icon.transform.origin.x - template_origin.x) / float(maxi(ABILITY_COUNT, 1))
	for ability_index in ABILITY_COUNT:
		if ability_index >= _offers.size():
			break
		var offer := _offers[ability_index]
		if String(offer.get("type", "")) != "ability":
			continue
		var card := _spawn_card(template_origin + Vector3(spacing * ability_index, 0.0, 0.0))
		_apply_ability_card(card, offer.get("ability") as AbilityDefinition)
		_apply_offer_price(card, offer)
		offer["card"] = card
		offer["clickable"] = card.get_node_or_null(^"ability_frame_base")
		_offers[ability_index] = offer

	var bottom_start := template_origin + Vector3(0.0, 0.0, 7.0)
	for lower_index in range(ABILITY_COUNT, ABILITY_COUNT + ARTIFACT_COUNT + CUBE_COUNT):
		if lower_index >= _offers.size():
			break
		var lower_offer := _offers[lower_index]
		var card_position := bottom_start + Vector3(spacing * float(lower_index - ABILITY_COUNT), 0.0, 0.0)
		var card := _spawn_card(card_position)
		var offer_type := String(lower_offer.get("type", ""))
		if offer_type == "artifact":
			_apply_artifact_card(card, lower_offer.get("artifact") as ArtifactDefinition)
		elif offer_type == "cube":
			_apply_cube_card(card, lower_offer.get("cube") as DiceDefinition)
		_apply_offer_price(card, lower_offer)
		lower_offer["card"] = card
		lower_offer["clickable"] = card.get_node_or_null(^"ability_frame_base")
		_offers[lower_index] = lower_offer

	for service_index in range(_offers.size() - 2, _offers.size()):
		_update_offer_visual(_offers[service_index])


func _spawn_card(position: Vector3) -> Node3D:
	var card := _ability_template.duplicate() as Node3D
	card.visible = true
	card.transform = Transform3D(_ability_template.transform.basis, position)
	add_child(card)
	_temporary_nodes.append(card)
	return card


func _apply_offer_price(card: Node3D, offer: Dictionary) -> void:
	if card == null:
		return
	var price_root := card.get_node_or_null(^"price_icon_ability") as MeshInstance3D
	if price_root == null and _price_template != null:
		price_root = _price_template.duplicate() as MeshInstance3D
		price_root.name = "price_icon_ability"
		card.add_child(price_root)
	if price_root == null:
		return
	price_root.visible = true
	offer["price_root"] = price_root
	_update_price_label(price_root, int(offer.get("price", 0)))


func _update_offer_visual(offer: Dictionary) -> void:
	var price_root := offer.get("price_root") as Node3D
	if price_root == null:
		return
	if bool(offer.get("sold", false)):
		_set_price_label_text(price_root, OFFER_STATUS_SOLD)
	else:
		_set_price_label_text(price_root, str(int(offer.get("price", 0))))


func _update_price_label(price_root: Node3D, value: int) -> void:
	_set_price_label_text(price_root, str(value))


func _set_price_label_text(price_root: Node3D, text: String) -> void:
	if price_root == null:
		return
	var label := price_root.get_node_or_null(^"Label3D") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "Label3D"
		label.pixel_size = 0.01
		label.font_size = 100
		label.outline_size = 30
		label.modulate = Color(0.976, 1.0, 0.0745, 1.0)
		label.outline_modulate = Color(0.66, 0.29, 0.149, 1.0)
		var label_basis := Basis(
			Vector3(0.608, 0.0, 0.0),
			Vector3(0.0, -0.00000004, 0.9999996),
			Vector3(0.0, -0.9999999, -0.00000004)
		)
		label.transform = Transform3D(label_basis, Vector3(0.2105, 0.0712, -0.019))
		price_root.add_child(label)
	label.text = text


func _apply_ability_card(card: Node3D, ability: AbilityDefinition) -> void:
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


func _apply_artifact_card(card: Node3D, artifact: ArtifactDefinition) -> void:
	_apply_ability_card(card, null)
	if card == null:
		return
	var title := card.get_node_or_null(^"ability_text") as Label3D
	if title != null:
		title.text = artifact.display_name if artifact != null else ""
	var description := card.get_node_or_null(^"abilitu_description") as Label3D
	if description != null:
		description.text = artifact.description if artifact != null else ""
	var icon := _ensure_artifact_icon_frame(card)
	if icon != null and artifact != null and artifact.sprite != null:
		_apply_texture_to_mesh(icon, artifact.sprite)


func _apply_cube_card(card: Node3D, cube: DiceDefinition) -> void:
	_apply_ability_card(card, null)
	if card == null:
		return
	var title := card.get_node_or_null(^"ability_text") as Label3D
	if title != null:
		title.text = cube.display_name if cube != null else ""
	var description := card.get_node_or_null(^"abilitu_description") as Label3D
	if description != null:
		description.text = cube.description if cube != null else ""
	var frame := _ensure_artifact_frame_node(card)
	if frame == null:
		return
	var icon_mesh := frame.get_node_or_null(^"artefact_icon_reward") as MeshInstance3D
	if icon_mesh != null:
		icon_mesh.visible = false
	var cube_node := _build_cube_preview_node(cube)
	if cube_node != null:
		frame.add_child(cube_node)


func _ensure_artifact_icon_frame(card: Node3D) -> MeshInstance3D:
	var frame := _ensure_artifact_frame_node(card)
	if frame == null:
		return null
	var icon_mesh := frame.get_node_or_null(^"artefact_icon_reward") as MeshInstance3D
	if icon_mesh != null:
		icon_mesh.visible = true
	return icon_mesh


func _ensure_artifact_frame_node(card: Node3D) -> MeshInstance3D:
	if _artifact_icon_template == null or card == null:
		return null
	var frame := card.get_node_or_null(^"artifact_reward_icon_frame") as MeshInstance3D
	if frame == null:
		frame = _artifact_icon_template.duplicate() as MeshInstance3D
		if frame == null:
			return null
		frame.name = "artifact_reward_icon_frame"
		var ability_icon := card.get_node_or_null(^"ability_icon") as MeshInstance3D
		if ability_icon != null:
			frame.transform = ability_icon.transform
		card.add_child(frame)
	frame.visible = true
	var ability_icon := card.get_node_or_null(^"ability_icon") as MeshInstance3D
	if ability_icon != null:
		ability_icon.visible = false
	return frame


func _build_cube_preview_node(cube_definition: DiceDefinition) -> Dice:
	if cube_definition == null:
		return null
	var cube_scene := load(BASE_CUBE_SCENE_PATH) as PackedScene
	if cube_scene == null:
		return null
	var cube := cube_scene.instantiate() as Dice
	if cube == null:
		return null
	cube.name = "cube_reward_preview"
	cube.definition = cube_definition
	cube.extra_size_multiplier = Vector3(1.5, 1.5, 1.5)
	cube.position = Vector3(0.0, 0.3, 0.0)
	cube.rotation_degrees = Vector3(45.0, 10.0, -120.0)
	cube.freeze = true
	cube.sleeping = true
	cube.lock_rotation = true
	cube.input_ray_pickable = false
	cube.collision_layer = 0
	cube.collision_mask = 0
	return cube


func _apply_texture_to_mesh(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	if mesh_instance == null or texture == null:
		return
	var material := mesh_instance.material_override as BaseMaterial3D
	if material == null:
		return
	var unique_material := material.duplicate() as BaseMaterial3D
	if unique_material == null:
		return
	unique_material.albedo_texture = texture
	mesh_instance.material_override = unique_material


func _calculate_ability_price(rarity: int) -> int:
	return _normalize_price((rarity + 1) * _rng.randi_range(ABILITY_PRICE_MULT_MIN, ABILITY_PRICE_MULT_MAX))


func _calculate_artifact_price(rarity: int) -> int:
	return _normalize_price((rarity + 2) * _rng.randi_range(ARTIFACT_PRICE_MULT_MIN, ARTIFACT_PRICE_MULT_MAX))


func _calculate_cube_price(rarity: int) -> int:
	return _normalize_price((rarity + 2) * _rng.randi_range(CUBE_PRICE_MULT_MIN, CUBE_PRICE_MULT_MAX))


func _normalize_price(value: int) -> int:
	return clampi(value, 1, 99)


func _roll_ability_rarity() -> int:
	var total_weight := RARITY_COMMON_WEIGHT + RARITY_UNCOMMON_WEIGHT + RARITY_RARE_WEIGHT + RARITY_UNIQUE_WEIGHT
	var roll := _rng.randf_range(0.0, total_weight)
	if roll < RARITY_COMMON_WEIGHT:
		return AbilityDefinition.Rarity.COMMON
	roll -= RARITY_COMMON_WEIGHT
	if roll < RARITY_UNCOMMON_WEIGHT:
		return AbilityDefinition.Rarity.UNCOMMON
	roll -= RARITY_UNCOMMON_WEIGHT
	if roll < RARITY_RARE_WEIGHT:
		return AbilityDefinition.Rarity.RARE
	return AbilityDefinition.Rarity.UNIQUE


func _roll_artifact_rarity() -> StringName:
	var total_weight := ARTIFACT_RARITY_COMMON_WEIGHT + ARTIFACT_RARITY_UNCOMMON_WEIGHT + ARTIFACT_RARITY_RARE_WEIGHT + ARTIFACT_RARITY_UNIQUE_WEIGHT
	var roll := _rng.randf_range(0.0, total_weight)
	if roll < ARTIFACT_RARITY_COMMON_WEIGHT:
		return &"common"
	roll -= ARTIFACT_RARITY_COMMON_WEIGHT
	if roll < ARTIFACT_RARITY_UNCOMMON_WEIGHT:
		return &"uncommon"
	roll -= ARTIFACT_RARITY_UNCOMMON_WEIGHT
	if roll < ARTIFACT_RARITY_RARE_WEIGHT:
		return &"rare"
	return &"unique"


func _roll_cube_rarity() -> int:
	var total_weight := CUBE_RARITY_COMMON_WEIGHT + CUBE_RARITY_UNCOMMON_WEIGHT + CUBE_RARITY_RARE_WEIGHT + CUBE_RARITY_UNIQUE_WEIGHT
	var roll := _rng.randf_range(0.0, total_weight)
	if roll < CUBE_RARITY_COMMON_WEIGHT:
		return DiceDefinition.Rarity.COMMON
	roll -= CUBE_RARITY_COMMON_WEIGHT
	if roll < CUBE_RARITY_UNCOMMON_WEIGHT:
		return DiceDefinition.Rarity.UNCOMMON
	roll -= CUBE_RARITY_UNCOMMON_WEIGHT
	if roll < CUBE_RARITY_RARE_WEIGHT:
		return DiceDefinition.Rarity.RARE
	return DiceDefinition.Rarity.UNIQUE


func _pick_ability_by_rarity_with_fallback(start_rarity: int, owned_ability_ids: Dictionary, offered_ability_ids: Dictionary) -> AbilityDefinition:
	var pool := _load_player_reward_abilities()
	for rarity in range(start_rarity, AbilityDefinition.Rarity.COMMON - 1, -1):
		var candidates: Array[AbilityDefinition] = []
		for ability in pool:
			if ability == null or ability.rarity != rarity:
				continue
			if owned_ability_ids.has(ability.ability_id):
				continue
			if offered_ability_ids.has(ability.ability_id):
				continue
			candidates.append(ability)
		if candidates.is_empty():
			continue
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return null


func _collect_owned_ability_ids() -> Dictionary:
	var owned := {}
	if _player == null:
		return owned
	for ability in _player.ability_loadout:
		if ability == null:
			continue
		owned[ability.ability_id] = true
	return owned


func _pick_artifact_by_rarity_with_fallback(start_rarity: StringName, blocked_ids: Dictionary) -> ArtifactDefinition:
	var pool := _load_artifact_catalog()
	for rarity in _build_artifact_fallback_chain(start_rarity):
		var candidates: Array[ArtifactDefinition] = []
		for artifact in pool:
			if artifact == null or artifact.rarity != rarity:
				continue
			if blocked_ids.has(artifact.artifact_id):
				continue
			candidates.append(artifact)
		if candidates.is_empty():
			continue
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return null


func _pick_cube_by_rarity_with_fallback(start_rarity: int, blocked_ids: Dictionary) -> DiceDefinition:
	var pool := _load_cube_catalog()
	for rarity in range(start_rarity, DiceDefinition.Rarity.COMMON - 1, -1):
		var candidates: Array[DiceDefinition] = []
		for cube in pool:
			if cube == null or cube.rarity != rarity:
				continue
			if blocked_ids.has(cube.resource_path):
				continue
			candidates.append(cube)
		if candidates.is_empty():
			continue
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return null


func _build_artifact_fallback_chain(start_rarity: StringName) -> Array[StringName]:
	var ordered: Array[StringName] = [&"common", &"uncommon", &"rare", &"unique"]
	var start_index := maxi(ordered.find(start_rarity), 0)
	var result: Array[StringName] = []
	for rarity_index in range(start_index, -1, -1):
		result.append(ordered[rarity_index])
	return result


func _load_player_reward_abilities() -> Array[AbilityDefinition]:
	var pool: Array[AbilityDefinition] = []
	for ability in _load_resources_from_directory(ABILITY_DEFINITIONS_DIRECTORY):
		var typed_ability := ability as AbilityDefinition
		if typed_ability == null:
			continue
		if typed_ability.upgrade_level != 0:
			continue
		pool.append(typed_ability)
	return pool


func _load_artifact_catalog() -> Array[ArtifactDefinition]:
	var pool: Array[ArtifactDefinition] = []
	for artifact in _load_resources_from_directory(ARTIFACT_DEFINITIONS_DIRECTORY):
		var typed_artifact := artifact as ArtifactDefinition
		if typed_artifact != null:
			pool.append(typed_artifact)
	return pool


func _load_cube_catalog() -> Array[DiceDefinition]:
	var pool: Array[DiceDefinition] = []
	for cube in _load_resources_from_directory(DICE_DEFINITIONS_DIRECTORY):
		var typed_cube := cube as DiceDefinition
		if typed_cube != null:
			pool.append(typed_cube)
	return pool


func _load_ability_catalog() -> Dictionary:
	var catalog := {}
	for resource in _load_resources_from_directory(ABILITY_DEFINITIONS_DIRECTORY):
		var ability := resource as AbilityDefinition
		if ability == null:
			continue
		catalog[ability.ability_id + "::" + str(ability.upgrade_level)] = ability
	return catalog


func _build_upgrade_entries() -> Array[Dictionary]:
	if _player == null:
		return []
	var upgradable: Array[Dictionary] = []
	for ability_index in range(_player.ability_loadout.size()):
		var base_ability := _player.ability_loadout[ability_index] as AbilityDefinition
		if base_ability == null:
			continue
		var upgrades := _resolve_follow_up_abilities(base_ability)
		if upgrades.is_empty():
			continue
		upgradable.append({
			"ability_index": ability_index,
			"upgrade_options": upgrades,
		})
	if upgradable.is_empty():
		return _build_reroll_upgrade_entries()
	var picked := upgradable[_rng.randi_range(0, upgradable.size() - 1)]
	var result: Array[Dictionary] = []
	for ability in picked.get("upgrade_options", []):
		var typed := ability as AbilityDefinition
		if typed == null:
			continue
		result.append({
			"label": typed.display_name,
			"ability": typed,
			"replace_index": int(picked.get("ability_index", -1)),
		})
	return result


func _build_reroll_upgrade_entries() -> Array[Dictionary]:
	if _player == null or _player.ability_loadout.is_empty():
		return []
	var random_index := _rng.randi_range(0, _player.ability_loadout.size() - 1)
	var selected := _player.ability_loadout[random_index] as AbilityDefinition
	var variants := _resolve_parallel_upgrade_options(selected)
	var result: Array[Dictionary] = []
	for ability in variants:
		if ability == null:
			continue
		result.append({
			"label": ability.display_name,
			"ability": ability,
			"replace_index": random_index,
		})
	return result


func _resolve_follow_up_abilities(base_ability: AbilityDefinition) -> Array[AbilityDefinition]:
	var resolved: Array[AbilityDefinition] = []
	if base_ability == null:
		return resolved
	for follow_up_id in base_ability.follow_up_ability_ids:
		var key := String(follow_up_id) + "::" + str(base_ability.upgrade_level + 1)
		var follow_up := _ability_catalog.get(key, null) as AbilityDefinition
		if follow_up != null:
			resolved.append(follow_up)
	return resolved


func _resolve_parallel_upgrade_options(current_ability: AbilityDefinition) -> Array[AbilityDefinition]:
	var resolved: Array[AbilityDefinition] = []
	if current_ability == null:
		return resolved
	var base_ability := _find_base_ability_for_family(current_ability)
	if base_ability != null:
		resolved = _resolve_follow_up_abilities(base_ability)
	var includes_current := false
	for ability in resolved:
		if ability != null and ability.resource_path == current_ability.resource_path:
			includes_current = true
			break
	if not includes_current:
		resolved.append(current_ability)
	return resolved


func _find_base_ability_for_family(ability: AbilityDefinition) -> AbilityDefinition:
	if ability == null:
		return null
	if ability.upgrade_level <= 0:
		return ability
	for candidate in _ability_catalog.values():
		var typed := candidate as AbilityDefinition
		if typed == null:
			continue
		if typed.ability_id == ability.ability_id and typed.upgrade_level == 0:
			return typed
	return ability


func _load_resources_from_directory(path: String) -> Array[Resource]:
	var dir := DirAccess.open(path)
	if dir == null:
		return []
	var resources: Array[Resource] = []
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			continue
		var full_path := path.path_join(file_name)
		var loaded := load(full_path)
		if loaded is Resource:
			resources.append(loaded)
	dir.list_dir_end()
	return resources


func _rarity_name_to_level(rarity: StringName) -> int:
	match rarity:
		&"common":
			return 0
		&"uncommon":
			return 1
		&"rare":
			return 2
		&"unique":
			return 3
	return 0


func _clear_generated_nodes() -> void:
	for node in _temporary_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_temporary_nodes.clear()


func _on_leave_shop_pressed() -> void:
	_open_global_map()


func _open_global_map() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene_path := GlobalMapRuntimeState.load_map_scene_path()
	if scene_path.is_empty():
		scene_path = GLOBAL_MAP_SCENE_PATH
	tree.change_scene_to_file(scene_path)
