extends Node3D

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")
const Dice = preload("res://content/dice/dice.gd")
const BattleSceneBootstrap = preload("res://content/combat/presentation/battle_scene_bootstrap.gd")
const BattleSceneViewRenderer = preload("res://content/combat/presentation/battle_scene_view_renderer.gd")
const PlayerAbilityInputController = preload("res://content/combat/presentation/player_ability_input_controller.gd")
const BattleTargetingService = preload("res://content/combat/presentation/battle_targeting_service.gd")
const BattleTurnOrchestrator = preload("res://content/combat/runtime/battle_turn_orchestrator.gd")
const BattleActionOrchestrator = preload("res://content/combat/runtime/battle_action_orchestrator.gd")
const PostBattleRewardFlow = preload("res://content/combat/reward/post_battle_reward_flow.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const MoneyUi = preload("res://ui/scripts/money_ui.gd")
const EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"

const ACTIVATION_ANIMATION_DURATION := 0.5

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
@onready var _artifact_reward_template: MeshInstance3D = $artefact_frame_reward
@onready var _money_ui: MoneyUi = $money_ui

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
var _has_spawned_post_battle_reward_dice := false
var _is_waiting_post_battle_reward_dice := false
var _has_processed_post_battle_reward_result := false
var _ability_reward_rng := RandomNumberGenerator.new()
var _generated_ability_reward_nodes: Array[Node3D] = []
var _ability_reward_entries: Array[Dictionary] = []
var _generated_artifact_reward_nodes: Array[Node3D] = []
var _artifact_reward_entries: Array[Dictionary] = []
var _generated_cube_reward_nodes: Array[Node3D] = []
var _cube_reward_entries: Array[Dictionary] = []
var _is_awaiting_ability_reward_selection := false
var _scene_bootstrap := BattleSceneBootstrap.new()
var _scene_view_renderer := BattleSceneViewRenderer.new()
var _player_ability_input_controller := PlayerAbilityInputController.new()
var _battle_targeting_service := BattleTargetingService.new()
var _battle_turn_orchestrator := BattleTurnOrchestrator.new()
var _battle_action_orchestrator := BattleActionOrchestrator.new()
var _post_battle_reward_flow := PostBattleRewardFlow.new()


func _ready() -> void:
	set_physics_process(true)
	_ability_reward_rng.randomize()
	_post_battle_reward_flow._clear_artifact_reward_cards(self)
	_post_battle_reward_flow._clear_cube_reward_cards(self)
	if _end_turn_button != null and not _end_turn_button.pressed.is_connected(_on_end_turn_button_pressed):
		_end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	if _event_button != null and not _event_button.pressed.is_connected(_on_event_button_pressed):
		_event_button.pressed.connect(_on_event_button_pressed)
	if battle_room_data == null:
		var pending_runtime_battle_room := GlobalMapRuntimeState.consume_pending_battle_room()
		if pending_runtime_battle_room != null:
			configure_from_battle_room(pending_runtime_battle_room)
		else:
			configure_from_battle_room(BattleRoomScript.create_test_battle_room())
	else:
		_apply_room_data()
		_initialize_battle_state()
	_bind_money_ui_to_player()


func configure_from_battle_room(next_battle_room: BattleRoom) -> void:
	_scene_bootstrap.configure_from_battle_room(self, next_battle_room)
	_bind_money_ui_to_player()


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
	if _battle_turn_orchestrator.is_turn_transition_in_progress():
		return
	var handled := await _player_ability_input_controller.handle_unhandled_input(
		self,
		event,
		_battle_targeting_service,
		_battle_action_orchestrator,
		_post_battle_reward_flow
	)
	if handled:
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _refresh_player_ability_snap_state() -> void:
	_player_ability_input_controller._refresh_player_ability_snap_state(self)


func _is_player_ability_frame_at_base(frame: MeshInstance3D) -> bool:
	return _player_ability_input_controller._is_player_ability_frame_at_base(self, frame)


func _register_player_ability_frame(frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	_player_ability_input_controller._register_player_ability_frame(self, frame, ability, ability_index)


func _register_player_ability_slots(frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	_player_ability_input_controller._register_player_ability_slots(self, frame, ability, ability_index)


func _set_mesh_tint(mesh_instance: MeshInstance3D, color: Color) -> void:
	_scene_view_renderer._set_mesh_tint(mesh_instance, color)


func _bind_money_ui_to_player() -> void:
	if _money_ui == null or battle_room_data == null:
		return
	_money_ui.bind_player(battle_room_data.player_instance)


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


func _activate_selected_ability(target_descriptor: Dictionary) -> void:
	await _battle_action_orchestrator._activate_selected_ability(self, target_descriptor)


func _play_ability_use_visual(frame_state: Dictionary, target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> void:
	await _battle_action_orchestrator._play_ability_use_visual(self, frame_state, target_descriptor, consumed_dice)


func _build_dice_assignments_for_frame(consumed_dice: Array[Dice], frame_state: Dictionary) -> Array[Dictionary]:
	return _battle_action_orchestrator._build_dice_assignments_for_frame(self, consumed_dice, frame_state)


func _apply_combatant_views_after_ability_resolution() -> void:
	_battle_action_orchestrator._apply_combatant_views_after_ability_resolution(self)


func _handle_post_battle_reward_dice() -> void:
	await _post_battle_reward_flow._handle_post_battle_reward_dice(self)


func _find_monster_ability_frame_state(monster_index: int, ability: AbilityDefinition) -> Dictionary:
	return _battle_action_orchestrator._find_monster_ability_frame_state(self, monster_index, ability)


func _execute_monster_ability(
	monster_index: int,
	ability: AbilityDefinition,
	target_descriptor: Dictionary,
	consumed_dice: Array[Dice]
) -> void:
	await _battle_action_orchestrator._execute_monster_ability(self, monster_index, ability, target_descriptor, consumed_dice)


func _resolve_activation_target_origin(target_descriptor: Dictionary, base_origin: Vector3) -> Vector3:
	return _battle_targeting_service.resolve_activation_target_origin(
		target_descriptor,
		base_origin,
		battle_room_data,
		_player_sprite,
		_monster_sprite_states
	)


func _initialize_battle_state() -> void:
	_scene_bootstrap._initialize_battle_state(self)


func _try_resolve_post_battle_reward_dice_result() -> void:
	_post_battle_reward_flow._try_resolve_post_battle_reward_dice_result(self)


func _find_post_battle_reward_die() -> Dice:
	return _post_battle_reward_flow._find_post_battle_reward_die(self)


func _show_ability_reward_options() -> void:
	_post_battle_reward_flow._show_ability_reward_options(self)


func _show_artifact_reward_options() -> void:
	_post_battle_reward_flow._show_artifact_reward_options(self)


func _show_cube_reward_options() -> void:
	_post_battle_reward_flow._show_cube_reward_options(self)


func _build_artifact_reward_options(count: int) -> Array[Dictionary]:
	return _post_battle_reward_flow._build_artifact_reward_options(self, count)


func _build_cube_reward_options(count: int) -> Array[Dictionary]:
	return _post_battle_reward_flow._build_cube_reward_options(self, count)


func _build_ability_reward_options(count: int) -> Array[Dictionary]:
	return _post_battle_reward_flow._build_ability_reward_options(self, count)


func _load_player_reward_abilities() -> Array[AbilityDefinition]:
	return _post_battle_reward_flow._load_player_reward_abilities()


func _collect_owned_ability_ids(player: Player) -> Dictionary:
	return _post_battle_reward_flow._collect_owned_ability_ids(player)


func _roll_reward_rarity() -> int:
	return _post_battle_reward_flow._roll_reward_rarity(self)


func _pick_ability_by_rarity_with_fallback(
	abilities: Array[AbilityDefinition],
	start_rarity: int,
	owned_ability_ids: Dictionary,
	offered_ability_ids: Dictionary
) -> AbilityDefinition:
	return _post_battle_reward_flow._pick_ability_by_rarity_with_fallback(
		abilities,
		start_rarity,
		owned_ability_ids,
		offered_ability_ids,
		self
	)

func _compute_reward_card_spacing_x() -> float:
	return _post_battle_reward_flow._compute_reward_card_spacing_x(self)


func _render_ability_reward_cards(entries: Array[Dictionary]) -> void:
	_post_battle_reward_flow._render_ability_reward_cards(self, entries)


func _apply_reward_card_visual(card_root: Node3D, ability: AbilityDefinition) -> void:
	_post_battle_reward_flow._apply_reward_card_visual(self, card_root, ability)


func _clear_ability_reward_cards() -> void:
	_post_battle_reward_flow._clear_ability_reward_cards(self)


func _clear_artifact_reward_cards() -> void:
	_post_battle_reward_flow._clear_artifact_reward_cards(self)


func _clear_cube_reward_cards() -> void:
	_post_battle_reward_flow._clear_cube_reward_cards(self)


func _resolve_reward_click(screen_point: Vector2) -> Dictionary:
	return _post_battle_reward_flow._resolve_reward_click(self, screen_point)


func _resolve_ability_reward_click(screen_point: Vector2) -> Dictionary:
	return _post_battle_reward_flow._resolve_ability_reward_click(self, screen_point)


func _select_ability_reward(entry: Dictionary) -> void:
	_post_battle_reward_flow._select_ability_reward(self, entry)


func _select_reward_entry(entry: Dictionary) -> void:
	_post_battle_reward_flow._select_reward_entry(self, entry)


func _start_current_turn() -> void:
	_battle_turn_orchestrator.start_current_turn(_build_turn_orchestrator_context())


func _throw_current_turn_dice() -> void:
	_battle_turn_orchestrator.throw_current_turn_dice(_build_turn_orchestrator_context())


func _build_dice_throw_request(dice_definition: DiceDefinition, metadata: Dictionary) -> DiceThrowRequest:
	return _battle_turn_orchestrator.build_dice_throw_request(dice_definition, metadata)


func _clear_board_dice() -> void:
	_battle_turn_orchestrator.clear_board_dice(_build_turn_orchestrator_context())


func _get_turn_dice(owner: StringName, monster_index: int = -1) -> Array[Dice]:
	return _battle_turn_orchestrator.get_turn_dice(_build_turn_orchestrator_context(), owner, monster_index)


func _are_current_monster_turn_dice_stopped() -> bool:
	return _battle_turn_orchestrator.are_current_monster_turn_dice_stopped(_build_turn_orchestrator_context())


func _on_end_turn_button_pressed() -> void:
	_battle_turn_orchestrator.on_end_turn_button_pressed(_build_turn_orchestrator_context())


func _on_event_button_pressed() -> void:
	var result := get_tree().change_scene_to_file(EVENT_ROOM_SCENE_PATH)
	if result != OK:
		push_warning("Failed to open event room scene: %s" % EVENT_ROOM_SCENE_PATH)


func _advance_to_next_turn() -> void:
	_battle_turn_orchestrator.advance_to_next_turn(_build_turn_orchestrator_context())


func _run_current_monster_turn() -> void:
	await _battle_turn_orchestrator.run_current_monster_turn(_build_turn_orchestrator_context())


func _build_turn_orchestrator_context() -> Dictionary:
	return {
		"owner_node": self,
		"battle_room_data": battle_room_data,
		"board": _board,
		"update_turn_ui": Callable(self, "_update_turn_ui"),
		"cancel_selected_ability": Callable(self, "_cancel_selected_ability"),
		"execute_monster_ability": Callable(self, "_execute_monster_ability"),
	}


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
	return _battle_targeting_service.project_mouse_to_horizontal_plane(_camera, get_viewport(), plane_y)


func _screen_point_hits_mesh(mesh_instance: MeshInstance3D, screen_point: Vector2) -> bool:
	return _battle_targeting_service.screen_point_hits_mesh(mesh_instance, screen_point, _camera)


func _has_player_dice_at_screen_point(screen_point: Vector2) -> bool:
	return _battle_targeting_service.has_player_dice_at_screen_point(screen_point, _camera, get_world_3d())


func _project_mesh_screen_rect(mesh_instance: MeshInstance3D) -> Rect2:
	return _battle_targeting_service.project_mesh_screen_rect(mesh_instance, _camera)
