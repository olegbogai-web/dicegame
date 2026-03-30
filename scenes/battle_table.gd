extends Node3D

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")
const Dice = preload("res://content/dice/dice.gd")
const BattleActivationAnimationRuntime = preload("res://content/combat/runtime/battle_activation_animation_runtime.gd")
const BattleSceneBootstrap = preload("res://content/combat/presentation/battle_scene_bootstrap.gd")
const BattleSceneViewRenderer = preload("res://content/combat/presentation/battle_scene_view_renderer.gd")
const PlayerAbilityInputController = preload("res://content/combat/presentation/player_ability_input_controller.gd")
const BattleTargetingService = preload("res://content/combat/presentation/battle_targeting_service.gd")
const BattleTurnOrchestrator = preload("res://content/combat/runtime/battle_turn_orchestrator.gd")
const EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"

const ACTIVATION_ANIMATION_DURATION := 0.5
const ACTIVATION_TARGET_LIFT_Y := 0.8
const SELECTED_FRAME_LIFT_Y := 1.9
const POST_BATTLE_REWARD_DICE_SIZE_MULTIPLIER := Vector3(4.0, 4.0, 4.0)
const POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER := 1.0
const POST_BATTLE_REWARD_DICE_DELAY_SECONDS := 1.0
const REWARD_CARD_FACE_ID := &"card_+"
const ABILITY_REWARD_OPTIONS_COUNT := 3
const ABILITY_REWARD_CARD_MIN_SPACING_X := 3.2
const ABILITY_REWARD_CARD_GAP_X := 0.35
const ABILITY_DEFINITIONS_DIRECTORY := "res://content/abilities/definitions"
const RARITY_COMMON_WEIGHT := 50.0
const RARITY_UNCOMMON_WEIGHT := 30.0
const RARITY_RARE_WEIGHT := 20.0
const RARITY_UNIQUE_WEIGHT := 10.0

@onready var _camera: Camera3D = $battle_camera
@onready var _board: BoardController = $board
@onready var _floor: MeshInstance3D = $floor
@onready var _player_sprite: MeshInstance3D = $player_sprite
@onready var _monster_sprite_template: MeshInstance3D = $monster_sprite
@onready var _player_ability_template: MeshInstance3D = $ability_frame
@onready var _monster_ability_template: MeshInstance3D = $ability_frame2
@onready var _end_turn_button: Button = $UI/EndTurnButton
@onready var _turn_status_label: Label = $UI/TurnStatusLabel
@onready var _event_button: Button = $UI/EventButton
@onready var _artifact_template: TextureRect = $UI/artefact
@onready var _ability_reward_template: Node3D = $ability_reward

var battle_room_data: BattleRoom
var _generated_monster_sprites: Array[Node] = []
var _generated_player_ability_frames: Array[Node] = []
var _generated_monster_ability_frames: Array[Node] = []
var _generated_artifact_icons: Array[TextureRect] = []
var _player_ability_slot_states: Array[Dictionary] = []
var _player_ability_frame_states: Array[Dictionary] = []
var _monster_ability_frame_states: Array[Dictionary] = []
var _monster_sprite_states: Array[Dictionary] = []
var _selected_ability_state: Dictionary = {}
var _selected_mouse_anchor := Vector3.ZERO
var _activation_in_progress := false
var _turn_transition_in_progress := false
var _has_spawned_post_battle_reward_dice := false
var _is_waiting_post_battle_reward_dice := false
var _has_processed_post_battle_reward_result := false
var _ability_reward_rng := RandomNumberGenerator.new()
var _generated_ability_reward_nodes: Array[Node3D] = []
var _ability_reward_entries: Array[Dictionary] = []
var _is_awaiting_ability_reward_selection := false
var _scene_bootstrap := BattleSceneBootstrap.new()
var _scene_view_renderer := BattleSceneViewRenderer.new()
var _player_ability_input_controller := PlayerAbilityInputController.new()
var _battle_targeting_service := BattleTargetingService.new()
var _battle_turn_orchestrator := BattleTurnOrchestrator.new()


func _ready() -> void:
	set_physics_process(true)
	_ability_reward_rng.randomize()
	if _end_turn_button != null and not _end_turn_button.pressed.is_connected(_on_end_turn_button_pressed):
		_end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	if _event_button != null and not _event_button.pressed.is_connected(_on_event_button_pressed):
		_event_button.pressed.connect(_on_event_button_pressed)
	if battle_room_data == null:
		configure_from_battle_room(BattleRoomScript.create_test_battle_room())
	else:
		_apply_room_data()
	_initialize_battle_state()


func configure_from_battle_room(next_battle_room: BattleRoom) -> void:
	_scene_bootstrap.configure_from_battle_room(self, next_battle_room)


func set_floor_textures(left_texture: Texture2D, right_texture: Texture2D) -> void:
	_scene_bootstrap.set_floor_textures(self, left_texture, right_texture)


func set_player_data(player: Player, sprite: Texture2D) -> void:
	_scene_bootstrap.set_player_data(self, player, sprite)


func set_monsters(monster_definitions: Array[MonsterDefinition]) -> void:
	_scene_bootstrap.set_monsters(self, monster_definitions)


func _ensure_battle_room_data() -> void:
	_scene_bootstrap._ensure_battle_room_data(self)


func _apply_room_data() -> void:
	_scene_view_renderer._apply_room_data(self)


func _apply_floor_textures() -> void:
	_scene_view_renderer._apply_floor_textures(self)


func _apply_player_sprite() -> void:
	_scene_view_renderer._apply_player_sprite(self)


func _apply_monster_sprites() -> void:
	_scene_view_renderer._apply_monster_sprites(self)


func _apply_ability_frames(
	abilities: Array[AbilityDefinition],
	template: MeshInstance3D,
	generated_nodes: Array[Node],
	track_player_slots: bool = false
) -> void:
	_scene_view_renderer._apply_ability_frames(self, abilities, template, generated_nodes, track_player_slots)


func _apply_monster_ability_frames() -> void:
	_scene_view_renderer._apply_monster_ability_frames(self)


func _register_monster_ability_frame(frame: MeshInstance3D, ability_entry: Dictionary, runtime_index: int) -> void:
	_scene_view_renderer._register_monster_ability_frame(self, frame, ability_entry, runtime_index)


func _apply_player_artifacts() -> void:
	_scene_view_renderer._apply_player_artifacts(self)


func _spawn_artifact_icon() -> TextureRect:
	return _scene_view_renderer._spawn_artifact_icon(self)


func _clear_generated_artifact_icons() -> void:
	_scene_view_renderer._clear_generated_artifact_icons(self)


func _apply_ability_icon(frame: MeshInstance3D, ability: AbilityDefinition) -> void:
	_scene_view_renderer._apply_ability_icon(self, frame, ability)


func _apply_dice_places(frame: MeshInstance3D, required_count: int) -> void:
	_scene_view_renderer._apply_dice_places(frame, required_count)


func _get_dice_place_nodes(frame: MeshInstance3D) -> Array[MeshInstance3D]:
	return _scene_view_renderer._get_dice_place_nodes(frame)


func _duplicate_sprite_template(template: MeshInstance3D, generated_nodes: Array[Node]) -> MeshInstance3D:
	return _scene_view_renderer._duplicate_sprite_template(self, template, generated_nodes)


func _duplicate_frame_template(template: MeshInstance3D, generated_nodes: Array[Node]) -> MeshInstance3D:
	return _scene_view_renderer._duplicate_frame_template(self, template, generated_nodes)


func _clear_generated_nodes(nodes: Array[Node]) -> void:
	_scene_view_renderer._clear_generated_nodes(self, nodes)


func _apply_health_bar(combatant_sprite: MeshInstance3D, health_ratio: float) -> void:
	_scene_view_renderer._apply_health_bar(self, combatant_sprite, health_ratio)


func _resolve_health_bar(combatant_sprite: MeshInstance3D) -> MeshInstance3D:
	return _scene_view_renderer._resolve_health_bar(combatant_sprite)


func _update_health_bar_transform(health_bar: MeshInstance3D, health_ratio: float) -> void:
	_scene_view_renderer._update_health_bar_transform(health_bar, health_ratio)


func _animate_health_bar(combatant_sprite: MeshInstance3D, target_ratio: float, delta: float) -> void:
	_scene_view_renderer._animate_health_bar(self, combatant_sprite, target_ratio, delta)


func _update_health_bars(delta: float) -> void:
	_scene_view_renderer._update_health_bars(self, delta)


func _refresh_status_visuals() -> void:
	_scene_view_renderer._refresh_status_visuals(self)


func _apply_monster_health_text(combatant_sprite: MeshInstance3D, health_values: Vector2i) -> void:
	_scene_view_renderer._apply_monster_health_text(combatant_sprite, health_values)


func _apply_health_text(combatant_sprite: MeshInstance3D, health_values: Vector2i, label_path: NodePath) -> void:
	_scene_view_renderer._apply_health_text(combatant_sprite, health_values, label_path)


func _apply_texture_to_mesh(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	_scene_view_renderer._apply_texture_to_mesh(self, mesh_instance, texture)


func _set_status_template_visible(is_visible: bool) -> void:
	_scene_view_renderer._set_status_template_visible(self, is_visible)


func _get_status_template() -> MeshInstance3D:
	return _scene_view_renderer._get_status_template(self)


func _clear_runtime_status_visuals(combatant_sprite: MeshInstance3D) -> void:
	_scene_view_renderer._clear_runtime_status_visuals(self, combatant_sprite)


func _apply_statuses_to_sprite(combatant_sprite: MeshInstance3D, descriptor: Dictionary) -> void:
	_scene_view_renderer._apply_statuses_to_sprite(self, combatant_sprite, descriptor)


func _build_centered_offsets(count: int, spacing: float) -> Array[float]:
	return _scene_view_renderer._build_centered_offsets(count, spacing)


func _physics_process(delta: float) -> void:
	_try_resolve_post_battle_reward_dice_result()
	_refresh_player_ability_snap_state()
	_update_health_bars(delta)
	_refresh_status_visuals()
	_update_turn_ui()
	if not _selected_ability_state.is_empty() and not _activation_in_progress:
		if not _is_ability_state_ready(_selected_ability_state):
			_cancel_selected_ability()
		else:
			_update_selected_ability_follow()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _activation_in_progress or _turn_transition_in_progress:
		return
	if battle_room_data == null:
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if _is_awaiting_ability_reward_selection and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var reward_click := _resolve_ability_reward_click((event as InputEventMouseButton).position)
		if not reward_click.is_empty():
			_select_ability_reward(reward_click)
			get_viewport().set_input_as_handled()
			return
	if not battle_room_data.is_player_turn() or battle_room_data.is_battle_over():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_selected_ability()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var mouse_event := event as InputEventMouseButton
	if _has_player_dice_at_screen_point(mouse_event.position):
		return

	var clicked_frame_state := _find_player_ability_frame_at_screen_point(mouse_event.position)
	if not clicked_frame_state.is_empty():
		if _is_ability_state_ready(clicked_frame_state):
			_select_player_ability(clicked_frame_state)
			get_viewport().set_input_as_handled()
			return

	if _selected_ability_state.is_empty():
		return

	var target_descriptor := _resolve_target_descriptor_at_screen_point(
		_selected_ability_state.get("ability") as AbilityDefinition,
		mouse_event.position
	)
	if target_descriptor.is_empty():
		return

	_activate_selected_ability(target_descriptor)
	get_viewport().set_input_as_handled()


func _refresh_player_ability_snap_state() -> void:
	_player_ability_input_controller._refresh_player_ability_snap_state(self)


func _is_player_ability_frame_at_base(frame: MeshInstance3D) -> bool:
	return _player_ability_input_controller._is_player_ability_frame_at_base(self, frame)


func _register_player_ability_frame(frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	_player_ability_input_controller._register_player_ability_frame(self, frame, ability, ability_index)


func _register_player_ability_slots(frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	_player_ability_input_controller._register_player_ability_slots(self, frame, ability, ability_index)


func _get_board_dice() -> Array[Dice]:
	var dice_list: Array[Dice] = []
	if _board == null:
		return dice_list
	for child in _board.get_children():
		if child is Dice and is_instance_valid(child):
			dice_list.append(child as Dice)
	return dice_list


func _find_dice_for_slot(slot_state: Dictionary, dice_list: Array[Dice]) -> Dice:
	return _player_ability_input_controller._find_dice_for_slot(slot_state, dice_list)


func _find_snap_candidate(slot_state: Dictionary, dice_list: Array[Dice], used_dice: Dictionary) -> Dice:
	return _player_ability_input_controller._find_snap_candidate(self, slot_state, dice_list, used_dice)


func _dice_matches_slot(dice: Dice, slot_state: Dictionary) -> bool:
	return _player_ability_input_controller._dice_matches_slot(self, dice, slot_state)


func _get_slot_target_position(dice_place: MeshInstance3D, dice: Dice) -> Vector3:
	return _player_ability_input_controller._get_slot_target_position(dice_place, dice)


func _update_player_ability_visuals(dice_list: Array[Dice]) -> void:
	_player_ability_input_controller._update_player_ability_visuals(self, dice_list)


func _get_active_drag_dice(dice_list: Array[Dice]) -> Dice:
	return _player_ability_input_controller._get_active_drag_dice(dice_list)


func _should_highlight_slot_for_dice(slot_state: Dictionary, assigned_dice: Dice, active_drag_dice: Dice) -> bool:
	return _player_ability_input_controller._should_highlight_slot_for_dice(self, slot_state, assigned_dice, active_drag_dice)


func _set_mesh_tint(mesh_instance: MeshInstance3D, color: Color) -> void:
	_scene_view_renderer._set_mesh_tint(mesh_instance, color)


func _find_player_ability_frame_at_screen_point(screen_point: Vector2) -> Dictionary:
	return _player_ability_input_controller._find_player_ability_frame_at_screen_point(self, screen_point)


func _select_player_ability(frame_state: Dictionary) -> void:
	_player_ability_input_controller._select_player_ability(self, frame_state)


func _cancel_selected_ability(skip_visual_reset: bool = false) -> void:
	_player_ability_input_controller._cancel_selected_ability(self, skip_visual_reset)


func _update_selected_ability_follow() -> void:
	_player_ability_input_controller._update_selected_ability_follow(self)


func _is_ability_state_ready(frame_state: Dictionary) -> bool:
	return _player_ability_input_controller._is_ability_state_ready(self, frame_state)


func _collect_ready_dice_for_frame(frame: MeshInstance3D) -> Array[Dice]:
	return _player_ability_input_controller._collect_ready_dice_for_frame(self, frame)


func _resolve_target_descriptor_at_screen_point(ability: AbilityDefinition, screen_point: Vector2) -> Dictionary:
	return _battle_targeting_service._resolve_target_descriptor_at_screen_point(self, ability, screen_point)


func _activate_selected_ability(target_descriptor: Dictionary) -> void:
	if _selected_ability_state.is_empty():
		return
	if not _is_ability_state_ready(_selected_ability_state):
		_cancel_selected_ability()
		return

	var frame_state := _selected_ability_state.duplicate(true)
	var consumed_dice := _collect_ready_dice_for_frame(frame_state.get("frame") as MeshInstance3D)
	_selected_ability_state.clear()
	await _play_ability_use_visual(frame_state, target_descriptor, consumed_dice)
	_refresh_player_ability_snap_state()


func _play_ability_use_visual(frame_state: Dictionary, target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> void:
	var frame := frame_state.get("frame") as MeshInstance3D
	var ability := frame_state.get("ability") as AbilityDefinition
	if frame == null or ability == null:
		return
	var base_origin: Vector3 = frame_state.get("base_origin", frame.transform.origin)
	var target_origin := _resolve_activation_target_origin(target_descriptor, base_origin)
	var dice_assignments := _build_dice_assignments_for_frame(consumed_dice, frame_state)
	var on_activate := func() -> void:
		var runtime_target_descriptor := target_descriptor.duplicate(true)
		runtime_target_descriptor["consumed_dice"] = consumed_dice
		battle_room_data.activate_current_turn_ability(ability, runtime_target_descriptor)
		_apply_combatant_views_after_ability_resolution()
	var on_finished := func() -> void:
		_activation_in_progress = false
		_update_turn_ui()
	_activation_in_progress = true
	await BattleActivationAnimationRuntime.play_ability_use_animation(
		self,
		frame,
		base_origin,
		target_origin,
		consumed_dice,
		dice_assignments,
		ACTIVATION_ANIMATION_DURATION,
		SELECTED_FRAME_LIFT_Y,
		on_activate,
		on_finished
	)


func _build_dice_assignments_for_frame(consumed_dice: Array[Dice], frame_state: Dictionary) -> Array[Dictionary]:
	var dice_assignments: Array[Dictionary] = []
	var dice_places: Array[MeshInstance3D] = []
	var raw_dice_places := frame_state.get("dice_places", []) as Array
	for dice_place in raw_dice_places:
		if dice_place is MeshInstance3D:
			dice_places.append(dice_place as MeshInstance3D)
	if dice_places.is_empty():
		var frame := frame_state.get("frame") as MeshInstance3D
		dice_places = _get_dice_place_nodes(frame)
	for index in mini(consumed_dice.size(), dice_places.size()):
		var dice := consumed_dice[index]
		var dice_place := dice_places[index]
		if dice == null or dice_place == null:
			continue
		dice_assignments.append({
			"dice": dice,
			"target_position": _get_slot_target_position(dice_place, dice),
		})
	return dice_assignments


func _apply_combatant_views_after_ability_resolution() -> void:
	_apply_player_sprite()
	_apply_monster_sprites()
	_update_turn_ui()
	if battle_room_data != null and battle_room_data.is_battle_over():
		print("[Debug][RewardFlow] Бой завершен. Статус: %s" % String(battle_room_data.battle_status))
		_clear_board_dice()
		_handle_post_battle_reward_dice()


func _handle_post_battle_reward_dice() -> void:
	if _has_spawned_post_battle_reward_dice or _is_waiting_post_battle_reward_dice:
		return
	_is_waiting_post_battle_reward_dice = true
	await get_tree().create_timer(POST_BATTLE_REWARD_DICE_DELAY_SECONDS).timeout
	_is_waiting_post_battle_reward_dice = false
	if _board == null or battle_room_data == null:
		return
	if battle_room_data.battle_status != &"victory":
		return
	print("[Debug][RewardFlow] Бой выигран. Запуск post-battle броска кубов награды.")
	var player := battle_room_data.player_instance
	if player == null:
		return
	var reward_cube := player.runtime_reward_cube
	var money_cube := player.runtime_money_cube
	if reward_cube == null and money_cube == null:
		return
	var requests: Array[DiceThrowRequest] = []
	if reward_cube != null:
		requests.append(_build_dice_throw_request(reward_cube, {"owner": &"reward"}))
	if money_cube != null:
		requests.append(_build_dice_throw_request(money_cube, {"owner": &"reward"}))
	if requests.is_empty():
		return
	for request in requests:
		request.extra_size_multiplier = POST_BATTLE_REWARD_DICE_SIZE_MULTIPLIER
	var spawned_dice := _board.throw_dice(requests)
	print("[Debug][RewardFlow] Куб награды/денег брошен. Количество кубов: %d." % spawned_dice.size())
	for dice_body in spawned_dice:
		if dice_body == null:
			continue
		dice_body.linear_velocity.y *= POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER
	_has_spawned_post_battle_reward_dice = true
	_has_processed_post_battle_reward_result = false


func _find_monster_ability_frame_state(monster_index: int, ability: AbilityDefinition) -> Dictionary:
	for frame_state in _monster_ability_frame_states:
		if int(frame_state.get("monster_index", -1)) != monster_index:
			continue
		if frame_state.get("ability") != ability:
			continue
		return frame_state
	return {}


func _execute_monster_ability(
	monster_index: int,
	ability: AbilityDefinition,
	target_descriptor: Dictionary,
	consumed_dice: Array[Dice]
) -> void:
	var frame_state := _find_monster_ability_frame_state(monster_index, ability)
	if frame_state.is_empty():
		var runtime_target_descriptor := target_descriptor.duplicate(true)
		runtime_target_descriptor["consumed_dice"] = consumed_dice
		battle_room_data.activate_current_turn_ability(ability, runtime_target_descriptor)
		_apply_combatant_views_after_ability_resolution()
		for dice in consumed_dice:
			if is_instance_valid(dice):
				dice.queue_free()
		return
	await _play_ability_use_visual(frame_state, target_descriptor, consumed_dice)


func _resolve_activation_target_origin(target_descriptor: Dictionary, base_origin: Vector3) -> Vector3:
	return _battle_targeting_service._resolve_activation_target_origin(self, target_descriptor, base_origin)


func _initialize_battle_state() -> void:
	_scene_bootstrap._initialize_battle_state(self)


func _try_resolve_post_battle_reward_dice_result() -> void:
	if not _has_spawned_post_battle_reward_dice or _has_processed_post_battle_reward_result:
		return
	var reward_dice := _find_post_battle_reward_die()
	if reward_dice == null:
		return
	var all_reward_dice := _get_turn_dice(&"reward")
	for dice in all_reward_dice:
		if dice == null or not dice.has_completed_first_stop():
			return
	_has_processed_post_battle_reward_result = true
	var reward_face := ""
	var reward_top_face := reward_dice.get_top_face()
	if reward_top_face != null:
		reward_face = reward_top_face.text_value
	print("[Debug][RewardFlow] На кубе награды выпало: %s." % reward_face)
	if StringName(reward_face) == REWARD_CARD_FACE_ID:
		_show_ability_reward_options()


func _find_post_battle_reward_die() -> Dice:
	var reward_dice := _get_turn_dice(&"reward")
	for dice in reward_dice:
		if dice == null:
			continue
		var dice_definition := dice.get_meta(&"definition", null) as DiceDefinition
		if dice_definition == null:
			continue
		if dice_definition.dice_name == "reward_cube":
			return dice
	return null


func _show_ability_reward_options() -> void:
	var options := _build_ability_reward_options(ABILITY_REWARD_OPTIONS_COUNT)
	if options.is_empty():
		print("[Debug][RewardFlow] Не удалось сгенерировать способности для награды.")
		return
	_render_ability_reward_cards(options)
	_is_awaiting_ability_reward_selection = true
	var ability_names: PackedStringArray = PackedStringArray()
	for entry in options:
		var ability := entry.get("ability") as AbilityDefinition
		if ability != null:
			ability_names.append(ability.display_name)
	print("[Debug][RewardFlow] Выпали способности: %s." % ", ".join(ability_names))


func _build_ability_reward_options(count: int) -> Array[Dictionary]:
	var player := battle_room_data.player_instance if battle_room_data != null else null
	if player == null:
		return []
	var available_abilities := _load_player_reward_abilities()
	if available_abilities.is_empty():
		return []
	var owned_ability_ids := _collect_owned_ability_ids(player)
	var generated: Array[Dictionary] = []
	var offered_ability_ids := {}
	for _index in count:
		var target_rarity := _roll_reward_rarity()
		var ability := _pick_ability_by_rarity_with_fallback(available_abilities, target_rarity, owned_ability_ids, offered_ability_ids)
		if ability == null:
			continue
		offered_ability_ids[ability.ability_id] = true
		generated.append({
			"ability": ability,
			"rolled_rarity": target_rarity,
		})
	return generated


func _load_player_reward_abilities() -> Array[AbilityDefinition]:
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
		var resource := ResourceLoader.load(path)
		var ability := resource as AbilityDefinition
		if ability == null:
			continue
		if ability.owner_scope != AbilityDefinition.OwnerScope.PLAYER and ability.owner_scope != AbilityDefinition.OwnerScope.ANY:
			continue
		abilities.append(ability)
	dir.list_dir_end()
	return abilities


func _collect_owned_ability_ids(player: Player) -> Dictionary:
	var owned := {}
	if player == null:
		return owned
	for ability in player.ability_loadout:
		if ability == null:
			continue
		owned[ability.ability_id] = true
	return owned


func _roll_reward_rarity() -> int:
	var total_weight := RARITY_COMMON_WEIGHT + RARITY_UNCOMMON_WEIGHT + RARITY_RARE_WEIGHT + RARITY_UNIQUE_WEIGHT
	var roll := _ability_reward_rng.randf_range(0.0, total_weight)
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
		return candidates[_ability_reward_rng.randi_range(0, candidates.size() - 1)]
	return null

func _compute_reward_card_spacing_x() -> float:
	if _ability_reward_template == null:
		return ABILITY_REWARD_CARD_MIN_SPACING_X
	var frame_base := _ability_reward_template.get_node_or_null(^"ability_frame_base") as MeshInstance3D
	if frame_base == null or frame_base.mesh == null:
		return ABILITY_REWARD_CARD_MIN_SPACING_X
	var card_size := frame_base.mesh.get_aabb().size
	var world_scale := frame_base.global_transform.basis.get_scale()
	var card_width := card_size.x * absf(world_scale.x)
	if card_width <= 0.0:
		return ABILITY_REWARD_CARD_MIN_SPACING_X
	return maxf(ABILITY_REWARD_CARD_MIN_SPACING_X, card_width + ABILITY_REWARD_CARD_GAP_X)


func _render_ability_reward_cards(entries: Array[Dictionary]) -> void:
	_clear_ability_reward_cards()
	if _ability_reward_template == null:
		return
	_ability_reward_template.visible = false
	_ability_reward_entries.clear()
	if entries.is_empty():
		return
	var spacing_x := _compute_reward_card_spacing_x()
	var offsets := _build_centered_offsets(entries.size(), spacing_x)
	var template_basis := _ability_reward_template.transform.basis
	var template_origin := _ability_reward_template.transform.origin
	for index in entries.size():
		var card_root := _ability_reward_template if index == 0 else (_ability_reward_template.duplicate() as Node3D)
		if card_root.get_parent() == null:
			add_child(card_root)
		card_root.visible = true
		card_root.transform = Transform3D(
			template_basis,
			template_origin + Vector3(offsets[index], 0.0, 0.0)
		)
		var ability := entries[index].get("ability") as AbilityDefinition
		_apply_reward_card_visual(card_root, ability)
		_ability_reward_entries.append({
			"node": card_root,
			"ability": ability,
		})
		if index > 0:
			_generated_ability_reward_nodes.append(card_root)


func _apply_reward_card_visual(card_root: Node3D, ability: AbilityDefinition) -> void:
	if card_root == null:
		return
	var icon_mesh := card_root.get_node_or_null(^"ability_icon") as MeshInstance3D
	if icon_mesh != null and ability != null and ability.icon != null:
		_apply_texture_to_mesh(icon_mesh, ability.icon)
	var title_label := card_root.get_node_or_null(^"ability_text") as Label3D
	if title_label != null:
		title_label.text = ability.display_name if ability != null else ""
	var description_label := card_root.get_node_or_null(^"abilitu_description") as Label3D
	if description_label != null:
		description_label.text = ability.description if ability != null else ""


func _clear_ability_reward_cards() -> void:
	for generated_node in _generated_ability_reward_nodes:
		if generated_node != null and is_instance_valid(generated_node):
			generated_node.queue_free()
	_generated_ability_reward_nodes.clear()
	_ability_reward_entries.clear()
	_is_awaiting_ability_reward_selection = false
	if _ability_reward_template != null:
		_ability_reward_template.visible = false


func _resolve_ability_reward_click(screen_point: Vector2) -> Dictionary:
	for index in range(_ability_reward_entries.size() - 1, -1, -1):
		var entry := _ability_reward_entries[index]
		var card_node := entry.get("node") as Node3D
		if card_node == null:
			continue
		var frame_mesh := card_node.get_node_or_null(^"ability_frame_base") as MeshInstance3D
		if _screen_point_hits_mesh(frame_mesh, screen_point):
			return entry
	return {}


func _select_ability_reward(entry: Dictionary) -> void:
	var selected_ability := entry.get("ability") as AbilityDefinition
	if selected_ability == null or battle_room_data == null or battle_room_data.player_instance == null:
		return
	var player := battle_room_data.player_instance
	for owned in player.ability_loadout:
		if owned != null and owned.ability_id == selected_ability.ability_id:
			_clear_ability_reward_cards()
			return
	player.ability_loadout.append(selected_ability)
	battle_room_data.player_view.abilities = player.ability_loadout.duplicate()
	print("[Debug][RewardFlow] Игрок выбрал способность: %s." % selected_ability.display_name)
	_player_ability_frame_states.clear()
	_player_ability_slot_states.clear()
	_apply_ability_frames(
		battle_room_data.get_player_abilities(),
		_player_ability_template,
		_generated_player_ability_frames,
		true
	)
	_clear_ability_reward_cards()


func _start_current_turn() -> void:
	_battle_turn_orchestrator._start_current_turn(self)


func _throw_current_turn_dice() -> void:
	_battle_turn_orchestrator._throw_current_turn_dice(self)


func _build_dice_throw_request(dice_definition: DiceDefinition, metadata: Dictionary) -> DiceThrowRequest:
	return _battle_turn_orchestrator._build_dice_throw_request(self, dice_definition, metadata)


func _clear_board_dice() -> void:
	_battle_turn_orchestrator._clear_board_dice(self)


func _get_turn_dice(owner: StringName, monster_index: int = -1) -> Array[Dice]:
	return _battle_turn_orchestrator._get_turn_dice(self, owner, monster_index)


func _are_current_monster_turn_dice_stopped() -> bool:
	return _battle_turn_orchestrator._are_current_monster_turn_dice_stopped(self)


func _on_end_turn_button_pressed() -> void:
	_battle_turn_orchestrator._on_end_turn_button_pressed(self)


func _on_event_button_pressed() -> void:
	var result := get_tree().change_scene_to_file(EVENT_ROOM_SCENE_PATH)
	if result != OK:
		push_warning("Failed to open event room scene: %s" % EVENT_ROOM_SCENE_PATH)


func _advance_to_next_turn() -> void:
	_battle_turn_orchestrator._advance_to_next_turn(self)


func _run_current_monster_turn() -> void:
	await _battle_turn_orchestrator._run_current_monster_turn(self)


func _update_turn_ui() -> void:
	if _end_turn_button != null:
		_end_turn_button.disabled = battle_room_data == null or not battle_room_data.is_player_turn() or _activation_in_progress or battle_room_data.is_battle_over()
	if _turn_status_label == null:
		return
	if battle_room_data == null:
		_turn_status_label.text = "Бой не готов"
		return
	if battle_room_data.battle_status == &"victory":
		_turn_status_label.text = "Победа: все монстры мертвы"
		return
	if battle_room_data.battle_status == &"defeat":
		_turn_status_label.text = "Поражение: игрок мертв"
		return
	if battle_room_data.is_player_turn():
		_turn_status_label.text = "Ход %d · Ход игрока" % battle_room_data.turn_counter
		return
	if battle_room_data.is_monster_turn():
		var suffix := " · ИИ ждет остановки кубов" if not _are_current_monster_turn_dice_stopped() else " · ИИ обрабатывает ход"
		_turn_status_label.text = "Ход %d · Ход монстра %d%s" % [battle_room_data.turn_counter, battle_room_data.current_monster_turn_index + 1, suffix]
		return
	_turn_status_label.text = "Ожидание боя"


func _project_mouse_to_horizontal_plane(plane_y: float) -> Vector3:
	return _battle_targeting_service._project_mouse_to_horizontal_plane(self, plane_y)


func _screen_point_hits_mesh(mesh_instance: MeshInstance3D, screen_point: Vector2) -> bool:
	return _battle_targeting_service._screen_point_hits_mesh(self, mesh_instance, screen_point)


func _has_player_dice_at_screen_point(screen_point: Vector2) -> bool:
	return _battle_targeting_service._has_player_dice_at_screen_point(self, screen_point)


func _project_mesh_screen_rect(mesh_instance: MeshInstance3D) -> Rect2:
	return _battle_targeting_service._project_mesh_screen_rect(self, mesh_instance)
