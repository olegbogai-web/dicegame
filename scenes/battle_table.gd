extends Node3D

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")
const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const BattleActivationAnimationRuntime = preload("res://content/combat/runtime/battle_activation_animation_runtime.gd")
const MonsterTurnRuntime = preload("res://content/monster_ai/monster_turn_runtime.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"

const SLOT_EMPTY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const SLOT_ASSIGNED_COLOR := Color(0.82, 0.9, 1.0, 1.0)
const SLOT_READY_COLOR := Color(0.2, 0.62, 1.0, 1.0)
const SLOT_HIGHLIGHT_COLOR := Color(0.36, 0.9, 0.48, 1.0)
const FRAME_READY_COLOR := Color(0.12, 0.55, 1.0, 1.0)
const FRAME_SELECTED_COLOR := Color(1.0, 0.92, 0.52, 1.0)
const TINT_MATERIAL_META_KEY := &"runtime_tint_material"
const HEALTH_BAR_META_KEY := &"health_bar_base_transform"
const HEALTH_BAR_CURRENT_RATIO_META_KEY := &"health_bar_current_ratio"
const HEALTH_BAR_TARGET_RATIO_META_KEY := &"health_bar_target_ratio"
const HEALTH_BAR_ANIMATION_DURATION := 0.5
const SELECTED_FRAME_LIFT_Y := 1.9
const SELECTED_FRAME_MOUSE_FOLLOW_FACTOR := 0.2
const ACTIVATION_ANIMATION_DURATION := 0.5
const ACTIVATION_TARGET_LIFT_Y := 0.8
const POST_BATTLE_REWARD_DICE_SIZE_MULTIPLIER := Vector3(4.0, 4.0, 4.0)
const POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER := 1.0
const POST_BATTLE_REWARD_DICE_DELAY_SECONDS := 1.0

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

var battle_room_data: BattleRoom
var _generated_monster_sprites: Array[Node] = []
var _generated_player_ability_frames: Array[Node] = []
var _generated_monster_ability_frames: Array[Node] = []
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


func _ready() -> void:
	set_physics_process(true)
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
	battle_room_data = next_battle_room
	_has_spawned_post_battle_reward_dice = false
	_is_waiting_post_battle_reward_dice = false
	if is_node_ready():
		_apply_room_data()
		_initialize_battle_state()


func set_floor_textures(left_texture: Texture2D, right_texture: Texture2D) -> void:
	_ensure_battle_room_data()
	battle_room_data.set_floor_textures(left_texture, right_texture)
	if is_node_ready():
		_apply_floor_textures()


func set_player_data(player: Player, sprite: Texture2D) -> void:
	_ensure_battle_room_data()
	battle_room_data.set_player_data(player, sprite)
	if is_node_ready():
		_apply_room_data()
		_initialize_battle_state()


func set_monsters(monster_definitions: Array[MonsterDefinition]) -> void:
	_ensure_battle_room_data()
	battle_room_data.set_monsters_from_definitions(monster_definitions)
	if is_node_ready():
		_apply_room_data()
		_initialize_battle_state()


func _ensure_battle_room_data() -> void:
	if battle_room_data == null:
		battle_room_data = BattleRoomScript.new()


func _apply_room_data() -> void:
	if battle_room_data == null:
		return
	_cancel_selected_ability(true)
	_player_ability_frame_states.clear()
	_monster_ability_frame_states.clear()
	_monster_sprite_states.clear()
	_apply_floor_textures()
	_apply_player_sprite()
	_apply_monster_sprites()
	_player_ability_slot_states.clear()
	_apply_ability_frames(
		battle_room_data.get_player_abilities(),
		_player_ability_template,
		_generated_player_ability_frames,
		true
	)
	_apply_monster_ability_frames()
	_refresh_player_ability_snap_state()
	_update_turn_ui()


func _apply_floor_textures() -> void:
	if _floor == null:
		return
	var floor_texture := battle_room_data.left_floor_texture
	if floor_texture == null:
		floor_texture = battle_room_data.right_floor_texture
	_apply_texture_to_mesh(_floor, floor_texture)


func _apply_player_sprite() -> void:
	var player_view := battle_room_data.player_view
	_player_sprite.visible = player_view != null and player_view.sprite != null
	if not _player_sprite.visible:
		return
	_apply_texture_to_mesh(_player_sprite, player_view.sprite)
	_player_sprite.transform = Transform3D(Basis.from_scale(player_view.base_scale), BattleRoomScript.PLAYER_SPRITE_POSITION)
	_apply_health_bar(_player_sprite, battle_room_data.get_player_health_ratio())
	_apply_health_text(_player_sprite, battle_room_data.get_player_health_values(), ^"HP_frame/HP_text_player")


func _apply_monster_sprites() -> void:
	_clear_generated_nodes(_generated_monster_sprites)
	_monster_sprite_states.clear()

	var monster_views := battle_room_data.monster_views
	if monster_views.is_empty():
		_monster_sprite_template.visible = false
		return

	var offsets := _build_centered_offsets(monster_views.size(), BattleRoomScript.STACK_SPACING_Z)
	for index in monster_views.size():
		var target_sprite := _monster_sprite_template if index == 0 else _duplicate_sprite_template(_monster_sprite_template, _generated_monster_sprites)
		var monster_view = monster_views[index]
		target_sprite.visible = monster_view != null and monster_view.sprite != null
		if not target_sprite.visible:
			continue
		_apply_texture_to_mesh(target_sprite, monster_view.sprite)
		target_sprite.transform = Transform3D(
			Basis.from_scale(monster_view.base_scale),
			BattleRoomScript.MONSTER_SPRITE_POSITION + Vector3(0.0, 0.0, offsets[index])
		)
		_apply_health_bar(target_sprite, battle_room_data.get_monster_health_ratio(index))
		_apply_monster_health_text(target_sprite, battle_room_data.get_monster_health_values(index))
		_monster_sprite_states.append({
			"sprite": target_sprite,
			"index": index,
		})


func _apply_ability_frames(
	abilities: Array[AbilityDefinition],
	template: MeshInstance3D,
	generated_nodes: Array[Node],
	track_player_slots: bool = false
) -> void:
	_clear_generated_nodes(generated_nodes)

	if abilities.is_empty():
		template.visible = false
		return

	var anchor := BattleRoomScript.PLAYER_ABILITY_FRAME_POSITION if template == _player_ability_template else BattleRoomScript.MONSTER_ABILITY_FRAME_POSITION
	var offsets := _build_centered_offsets(abilities.size(), BattleRoomScript.STACK_SPACING_Z)
	for index in abilities.size():
		var frame := template if index == 0 else _duplicate_frame_template(template, generated_nodes)
		var ability := abilities[index]
		frame.visible = ability != null
		if ability == null:
			continue
		frame.transform = Transform3D(frame.transform.basis, anchor + Vector3(0.0, 0.0, offsets[index]))
		_apply_ability_icon(frame, ability)
		_apply_dice_places(frame, battle_room_data.get_required_dice_slots(ability))
		if track_player_slots:
			_register_player_ability_frame(frame, ability, index)
			_register_player_ability_slots(frame, ability, index)


func _apply_monster_ability_frames() -> void:
	_clear_generated_nodes(_generated_monster_ability_frames)
	_monster_ability_frame_states.clear()
	var monster_entries := battle_room_data.get_monster_ability_entries()
	if monster_entries.is_empty():
		_monster_ability_template.visible = false
		return

	var offsets := _build_centered_offsets(monster_entries.size(), BattleRoomScript.STACK_SPACING_Z)
	for index in monster_entries.size():
		var frame := _monster_ability_template if index == 0 else _duplicate_frame_template(_monster_ability_template, _generated_monster_ability_frames)
		var entry := monster_entries[index]
		var ability := entry.get("ability") as AbilityDefinition
		frame.visible = ability != null
		if ability == null:
			continue
		frame.transform = Transform3D(
			frame.transform.basis,
			BattleRoomScript.MONSTER_ABILITY_FRAME_POSITION + Vector3(0.0, 0.0, offsets[index])
		)
		_apply_ability_icon(frame, ability)
		_apply_dice_places(frame, battle_room_data.get_required_dice_slots(ability))
		_register_monster_ability_frame(frame, entry, index)


func _register_monster_ability_frame(frame: MeshInstance3D, ability_entry: Dictionary, runtime_index: int) -> void:
	_monster_ability_frame_states.append({
		"frame": frame,
		"ability": ability_entry.get("ability") as AbilityDefinition,
		"monster_index": int(ability_entry.get("monster_index", -1)),
		"ability_index": int(ability_entry.get("ability_index", runtime_index)),
		"base_origin": frame.transform.origin,
		"dice_places": _get_dice_place_nodes(frame),
	})


func _apply_ability_icon(frame: MeshInstance3D, ability: AbilityDefinition) -> void:
	var icon_node := frame.get_node_or_null(^"player_ability") as MeshInstance3D
	if icon_node == null:
		icon_node = frame.get_node_or_null(^"monster_ability") as MeshInstance3D
	if icon_node == null:
		return
	icon_node.visible = ability.icon != null
	if icon_node.visible:
		_apply_texture_to_mesh(icon_node, ability.icon)


func _apply_dice_places(frame: MeshInstance3D, required_count: int) -> void:
	var dice_places := _get_dice_place_nodes(frame)
	if dice_places.is_empty():
		return

	var active_count := clampi(required_count, 0, dice_places.size())
	var base_positions := BattleRoomScript.DICE_PLACE_Z_POSITIONS
	var spacing := 0.0
	if base_positions.size() >= 2:
		spacing = absf(base_positions[1] - base_positions[0])
	var center = base_positions[1] if base_positions.size() >= 2 else 0.0

	var slot_positions := _build_centered_offsets(active_count, spacing)
	for index in dice_places.size():
		var dice_place := dice_places[index]
		if index >= active_count:
			dice_place.visible = false
			continue
		dice_place.visible = true
		var origin := dice_place.transform.origin
		origin.z = center + slot_positions[index]
		dice_place.transform = Transform3D(dice_place.transform.basis, origin)


func _get_dice_place_nodes(frame: MeshInstance3D) -> Array[MeshInstance3D]:
	var dice_places: Array[MeshInstance3D] = []
	for child in frame.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("dice_place"):
			dice_places.append(child as MeshInstance3D)
	dice_places.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return String(a.name) < String(b.name)
	)
	return dice_places


func _duplicate_sprite_template(template: MeshInstance3D, generated_nodes: Array[Node]) -> MeshInstance3D:
	var duplicate := template.duplicate() as MeshInstance3D
	duplicate.name = "%s_runtime_%d" % [template.name, generated_nodes.size()]
	add_child(duplicate)
	generated_nodes.append(duplicate)
	return duplicate


func _duplicate_frame_template(template: MeshInstance3D, generated_nodes: Array[Node]) -> MeshInstance3D:
	var duplicate := template.duplicate() as MeshInstance3D
	duplicate.name = "%s_runtime_%d" % [template.name, generated_nodes.size()]
	add_child(duplicate)
	generated_nodes.append(duplicate)
	return duplicate


func _clear_generated_nodes(nodes: Array[Node]) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()


func _apply_health_bar(combatant_sprite: MeshInstance3D, health_ratio: float) -> void:
	var resolved_ratio := clampf(health_ratio, 0.0, 1.0)
	var health_bar := _resolve_health_bar(combatant_sprite)
	if health_bar == null:
		return

	if not health_bar.has_meta(HEALTH_BAR_META_KEY):
		health_bar.set_meta(HEALTH_BAR_META_KEY, health_bar.transform)
	if not health_bar.has_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY):
		health_bar.set_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY, resolved_ratio)
		_update_health_bar_transform(health_bar, resolved_ratio)
	health_bar.set_meta(HEALTH_BAR_TARGET_RATIO_META_KEY, resolved_ratio)


func _resolve_health_bar(combatant_sprite: MeshInstance3D) -> MeshInstance3D:
	if combatant_sprite == null:
		return null

	var health_bar := combatant_sprite.get_node_or_null(^"HP_frame/HP_bar_player") as MeshInstance3D
	if health_bar == null:
		health_bar = combatant_sprite.get_node_or_null(^"HP_frame_monster/HP_bar_monster") as MeshInstance3D
	return health_bar


func _update_health_bar_transform(health_bar: MeshInstance3D, health_ratio: float) -> void:
	if health_bar == null or not health_bar.has_meta(HEALTH_BAR_META_KEY):
		return

	var resolved_ratio := clampf(health_ratio, 0.0, 1.0)
	var base_transform: Transform3D = health_bar.get_meta(HEALTH_BAR_META_KEY)
	var base_scale := base_transform.basis.get_scale()
	var target_scale_x := base_scale.x * resolved_ratio
	health_bar.visible = not is_zero_approx(target_scale_x)
	if not health_bar.visible:
		return

	var target_basis := Basis.from_scale(Vector3(target_scale_x, base_scale.y, base_scale.z))
	var target_origin := base_transform.origin
	target_origin.x = base_transform.origin.x - (base_scale.x - target_scale_x) * 1
	health_bar.transform = Transform3D(target_basis, target_origin)


func _animate_health_bar(combatant_sprite: MeshInstance3D, target_ratio: float, delta: float) -> void:
	var health_bar := _resolve_health_bar(combatant_sprite)
	if health_bar == null:
		return
	if not health_bar.has_meta(HEALTH_BAR_META_KEY):
		health_bar.set_meta(HEALTH_BAR_META_KEY, health_bar.transform)
	if not health_bar.has_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY):
		health_bar.set_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY, clampf(target_ratio, 0.0, 1.0))
	if not health_bar.has_meta(HEALTH_BAR_TARGET_RATIO_META_KEY):
		health_bar.set_meta(HEALTH_BAR_TARGET_RATIO_META_KEY, clampf(target_ratio, 0.0, 1.0))

	var current_ratio := float(health_bar.get_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY, target_ratio))
	var resolved_target_ratio := clampf(float(health_bar.get_meta(HEALTH_BAR_TARGET_RATIO_META_KEY, target_ratio)), 0.0, 1.0)
	var step := 1.0 if HEALTH_BAR_ANIMATION_DURATION <= 0.0 else minf(delta / HEALTH_BAR_ANIMATION_DURATION, 1.0)
	var next_ratio := move_toward(current_ratio, resolved_target_ratio, absf(resolved_target_ratio - current_ratio) * step)
	health_bar.set_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY, next_ratio)
	_update_health_bar_transform(health_bar, next_ratio)


func _update_health_bars(delta: float) -> void:
	if battle_room_data == null:
		return
	if battle_room_data.player_view != null:
		_animate_health_bar(_player_sprite, battle_room_data.get_player_health_ratio(), delta)
	for monster_state in _monster_sprite_states:
		var sprite := monster_state.get("sprite") as MeshInstance3D
		var monster_index := int(monster_state.get("index", -1))
		if sprite == null or monster_index < 0:
			continue
		_animate_health_bar(sprite, battle_room_data.get_monster_health_ratio(monster_index), delta)


func _apply_monster_health_text(combatant_sprite: MeshInstance3D, health_values: Vector2i) -> void:
	_apply_health_text(combatant_sprite, health_values, ^"HP_frame_monster/HP_text_monster")


func _apply_health_text(combatant_sprite: MeshInstance3D, health_values: Vector2i, label_path: NodePath) -> void:
	if combatant_sprite == null:
		return

	var health_label := combatant_sprite.get_node_or_null(label_path) as Label3D
	if health_label == null:
		return

	health_label.text = "%d/%d" % [maxi(health_values.x, 0), maxi(health_values.y, 0)]
	health_label.modulate = Color(1.0, 0.45, 0.75, 1.0)
	health_label.visible = health_values.y > 0


func _apply_texture_to_mesh(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	if mesh_instance == null:
		return
	var material := mesh_instance.material_override
	if material == null:
		material = StandardMaterial3D.new()
	else:
		material = material.duplicate()
	if material is StandardMaterial3D:
		material.albedo_texture = texture
	mesh_instance.material_override = material


func _build_centered_offsets(count: int, spacing: float) -> Array[float]:
	var offsets: Array[float] = []
	if count <= 0:
		return offsets
	var start := -0.5 * spacing * float(count - 1)
	for index in count:
		offsets.append(start + spacing * float(index))
	return offsets


func _physics_process(delta: float) -> void:
	_refresh_player_ability_snap_state()
	_update_health_bars(delta)
	_update_turn_ui()
	if not _selected_ability_state.is_empty() and not _activation_in_progress:
		if not _is_ability_state_ready(_selected_ability_state):
			_cancel_selected_ability()
		else:
			_update_selected_ability_follow()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _activation_in_progress or _turn_transition_in_progress:
		return
	if battle_room_data == null or not battle_room_data.is_player_turn() or battle_room_data.is_battle_over():
		return
	if event is InputEventMouseButton and not event.pressed:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_selected_ability()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var mouse_event := event as InputEventMouseButton
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
	if _player_ability_slot_states.is_empty():
		return

	var dice_list := _get_board_dice()
	if battle_room_data == null or not battle_room_data.is_player_turn() or battle_room_data.is_battle_over():
		for dice in dice_list:
			if dice.get_assigned_ability_slot_id() != &"":
				dice.clear_ability_slot()
		_update_player_ability_visuals([])
		return

	var slot_by_id := {}
	for slot_state in _player_ability_slot_states:
		slot_by_id[slot_state["slot_id"]] = slot_state

	for dice in dice_list:
		var assigned_slot_id := dice.get_assigned_ability_slot_id()
		if assigned_slot_id == &"":
			continue
		if not slot_by_id.has(assigned_slot_id):
			dice.clear_ability_slot()
			continue
		var assigned_slot: Dictionary = slot_by_id[assigned_slot_id]
		if not _dice_matches_slot(dice, assigned_slot):
			dice.clear_ability_slot()

	var used_dice := {}
	for slot_state in _player_ability_slot_states:
		var assigned_dice := _find_dice_for_slot(slot_state, dice_list)
		if assigned_dice != null:
			used_dice[assigned_dice.get_instance_id()] = true
			var target_position := _get_slot_target_position(slot_state["dice_place"], assigned_dice)
			assigned_dice.assign_ability_slot(slot_state["slot_id"], target_position)
			continue
		if not _is_player_ability_frame_at_base(slot_state["frame"] as MeshInstance3D):
			continue

		var candidate := _find_snap_candidate(slot_state, dice_list, used_dice)
		if candidate == null:
			continue
		used_dice[candidate.get_instance_id()] = true
		candidate.assign_ability_slot(slot_state["slot_id"], _get_slot_target_position(slot_state["dice_place"], candidate))

	_update_player_ability_visuals(dice_list)


func _is_player_ability_frame_at_base(frame: MeshInstance3D) -> bool:
	if frame == null:
		return false
	for frame_state in _player_ability_frame_states:
		if frame_state.get("frame") != frame:
			continue
		var base_origin: Vector3 = frame_state.get("base_origin", frame.transform.origin)
		return frame.transform.origin.is_equal_approx(base_origin)
	return true


func _register_player_ability_frame(frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	_player_ability_frame_states.append({
		"frame": frame,
		"ability": ability,
		"ability_index": ability_index,
		"base_origin": frame.transform.origin,
	})


func _register_player_ability_slots(frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	var dice_places := _get_dice_place_nodes(frame)
	var slot_conditions := BattleAbilityRuntime.build_slot_conditions(ability)
	for index in dice_places.size():
		var dice_place := dice_places[index]
		if index >= slot_conditions.size() or not dice_place.visible:
			continue
		_player_ability_slot_states.append({
			"slot_id": StringName("player_%s_%d_%d" % [ability.ability_id, ability_index, index]),
			"ability_id": ability.ability_id,
			"ability": ability,
			"frame": frame,
			"dice_place": dice_place,
			"condition": slot_conditions[index],
		})


func _get_board_dice() -> Array[Dice]:
	var dice_list: Array[Dice] = []
	if _board == null:
		return dice_list
	for child in _board.get_children():
		if child is Dice and is_instance_valid(child):
			dice_list.append(child as Dice)
	return dice_list


func _find_dice_for_slot(slot_state: Dictionary, dice_list: Array[Dice]) -> Dice:
	for dice in dice_list:
		if dice.get_assigned_ability_slot_id() == slot_state["slot_id"]:
			return dice
	return null


func _find_snap_candidate(slot_state: Dictionary, dice_list: Array[Dice], used_dice: Dictionary) -> Dice:
	var best_candidate: Dice
	var best_distance := INF
	var dice_place := slot_state["dice_place"] as MeshInstance3D
	for dice in dice_list:
		if used_dice.has(dice.get_instance_id()):
			continue
		if dice.is_being_dragged() or dice.get_assigned_ability_slot_id() != &"":
			continue
		if not _dice_matches_slot(dice, slot_state):
			continue
		var distance := dice.global_position.distance_to(_get_slot_target_position(dice_place, dice))
		if distance > dice.ability_snap_distance or distance >= best_distance:
			continue
		best_distance = distance
		best_candidate = dice
	return best_candidate


func _dice_matches_slot(dice: Dice, slot_state: Dictionary) -> bool:
	var condition := slot_state.get("condition") as AbilityDiceCondition
	if dice == null or condition == null:
		return false

	var top_face_value := dice.get_top_face_value()
	if top_face_value < 0 or not condition.matches_value(top_face_value):
		return false

	if condition.requires_face_filter():
		var top_face := dice.get_top_face()
		if top_face == null or not condition.accepted_face_ids.has(top_face.text_value):
			return false

	var dice_tags := dice.get_match_tags()
	for required_tag in condition.required_tags:
		if not dice_tags.has(required_tag):
			return false
	for forbidden_tag in condition.forbidden_tags:
		if dice_tags.has(forbidden_tag):
			return false

	return BattleAbilityRuntime.is_die_usable_for_ability(dice, slot_state.get("ability") as AbilityDefinition, condition)


func _get_slot_target_position(dice_place: MeshInstance3D, dice: Dice) -> Vector3:
	var offset_y := 0.1
	if dice != null and dice.definition != null:
		offset_y = dice.definition.get_resolved_size().y * dice.extra_size_multiplier.y * 0.5
	return dice_place.global_position + Vector3.UP * offset_y


func _update_player_ability_visuals(dice_list: Array[Dice]) -> void:
	var ability_status := {}
	var active_drag_dice := _get_active_drag_dice(dice_list)
	for slot_state in _player_ability_slot_states:
		var assigned_dice := _find_dice_for_slot(slot_state, dice_list)
		var is_ready := assigned_dice != null and assigned_dice.is_snapped_to_ability_slot()
		var slot_color := SLOT_EMPTY_COLOR
		if _should_highlight_slot_for_dice(slot_state, assigned_dice, active_drag_dice):
			slot_color = SLOT_HIGHLIGHT_COLOR
		elif assigned_dice != null:
			slot_color = SLOT_ASSIGNED_COLOR
		if is_ready:
			slot_color = SLOT_READY_COLOR
		_set_mesh_tint(slot_state["dice_place"], slot_color)
		var ability_key := (slot_state["frame"] as MeshInstance3D).get_instance_id()
		if not ability_status.has(ability_key):
			ability_status[ability_key] = {
				"frame": slot_state["frame"],
				"ready": true,
			}
		if not is_ready:
			ability_status[ability_key]["ready"] = false

	for slot_info in ability_status.values():
		var frame := slot_info["frame"] as MeshInstance3D
		var tint := FRAME_READY_COLOR if slot_info["ready"] else SLOT_EMPTY_COLOR
		if not _selected_ability_state.is_empty() and _selected_ability_state.get("frame") == frame:
			tint = FRAME_SELECTED_COLOR
		_set_mesh_tint(frame, tint)


func _get_active_drag_dice(dice_list: Array[Dice]) -> Dice:
	for dice in dice_list:
		if dice.is_being_dragged():
			return dice
	return null


func _should_highlight_slot_for_dice(slot_state: Dictionary, assigned_dice: Dice, active_drag_dice: Dice) -> bool:
	if active_drag_dice == null or assigned_dice != null:
		return false
	return _dice_matches_slot(active_drag_dice, slot_state)


func _set_mesh_tint(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return
	var material: StandardMaterial3D = null
	if mesh_instance.has_meta(TINT_MATERIAL_META_KEY):
		material = mesh_instance.get_meta(TINT_MATERIAL_META_KEY) as StandardMaterial3D
	if material == null:
		if mesh_instance.material_override is StandardMaterial3D:
			material = (mesh_instance.material_override as StandardMaterial3D).duplicate()
		else:
			material = StandardMaterial3D.new()
		mesh_instance.set_meta(TINT_MATERIAL_META_KEY, material)
		mesh_instance.material_override = material
	material.albedo_color = color


func _find_player_ability_frame_at_screen_point(screen_point: Vector2) -> Dictionary:
	for index in range(_player_ability_frame_states.size() - 1, -1, -1):
		var frame_state := _player_ability_frame_states[index]
		var frame := frame_state.get("frame") as MeshInstance3D
		if _screen_point_hits_mesh(frame, screen_point):
			return frame_state
	return {}


func _select_player_ability(frame_state: Dictionary) -> void:
	if frame_state.is_empty():
		return
	if not _selected_ability_state.is_empty() and _selected_ability_state.get("frame") == frame_state.get("frame"):
		return
	_cancel_selected_ability()
	_selected_ability_state = frame_state.duplicate()
	var selected_base_origin: Vector3 = frame_state.get("base_origin", Vector3.ZERO)
	_selected_mouse_anchor = _project_mouse_to_horizontal_plane(selected_base_origin.y)
	_update_selected_ability_follow()


func _cancel_selected_ability(skip_visual_reset: bool = false) -> void:
	if _selected_ability_state.is_empty():
		return
	if not skip_visual_reset:
		var frame := _selected_ability_state.get("frame") as MeshInstance3D
		var base_origin: Vector3 = _selected_ability_state.get("base_origin", Vector3.ZERO)
		if is_instance_valid(frame):
			frame.transform = Transform3D(frame.transform.basis, base_origin)
	_selected_ability_state.clear()
	_selected_mouse_anchor = Vector3.ZERO


func _update_selected_ability_follow() -> void:
	var frame := _selected_ability_state.get("frame") as MeshInstance3D
	if not is_instance_valid(frame):
		_selected_ability_state.clear()
		return
	var base_origin: Vector3 = _selected_ability_state.get("base_origin", frame.transform.origin)
	var mouse_world := _project_mouse_to_horizontal_plane(base_origin.y)
	var mouse_delta := (mouse_world - _selected_mouse_anchor) * SELECTED_FRAME_MOUSE_FOLLOW_FACTOR
	var target_origin := base_origin + Vector3(mouse_delta.x, SELECTED_FRAME_LIFT_Y, mouse_delta.z)
	frame.transform = Transform3D(frame.transform.basis, target_origin)


func _is_ability_state_ready(frame_state: Dictionary) -> bool:
	var frame := frame_state.get("frame") as MeshInstance3D
	if frame == null:
		return false
	var relevant_slot_count := 0
	for slot_state in _player_ability_slot_states:
		if slot_state.get("frame") != frame:
			continue
		relevant_slot_count += 1
		var assigned_dice := _find_dice_for_slot(slot_state, _get_board_dice())
		if assigned_dice == null or not assigned_dice.is_snapped_to_ability_slot():
			return false
	return relevant_slot_count > 0 or battle_room_data.get_required_dice_slots(frame_state.get("ability") as AbilityDefinition) == 0


func _collect_ready_dice_for_frame(frame: MeshInstance3D) -> Array[Dice]:
	var dice_list := _get_board_dice()
	var consumed_dice: Array[Dice] = []
	for slot_state in _player_ability_slot_states:
		if slot_state.get("frame") != frame:
			continue
		var assigned_dice := _find_dice_for_slot(slot_state, dice_list)
		if assigned_dice != null and assigned_dice.is_snapped_to_ability_slot():
			consumed_dice.append(assigned_dice)
	return consumed_dice


func _resolve_target_descriptor_at_screen_point(ability: AbilityDefinition, screen_point: Vector2) -> Dictionary:
	if battle_room_data == null or ability == null or ability.target_rule == null:
		return {}

	match ability.target_rule.get_target_hint():
		&"self":
			if _screen_point_hits_mesh(_player_sprite, screen_point) and battle_room_data.can_target_player():
				return {
					"kind": &"player",
				}
		&"single_enemy":
			for index in range(_monster_sprite_states.size() - 1, -1, -1):
				var monster_state := _monster_sprite_states[index]
				var sprite := monster_state.get("sprite") as MeshInstance3D
				var monster_index := int(monster_state.get("index", -1))
				if _screen_point_hits_mesh(sprite, screen_point) and battle_room_data.can_target_monster(monster_index):
					return {
						"kind": &"monster",
						"index": monster_index,
					}
		&"all_enemies":
			for monster_state in _monster_sprite_states:
				var sprite := monster_state.get("sprite") as MeshInstance3D
				if _screen_point_hits_mesh(sprite, screen_point):
					return {
						"kind": &"all_monsters",
					}
			if _screen_point_hits_mesh(_floor, screen_point):
				return {
					"kind": &"all_monsters",
				}
		&"global":
			return {
				"kind": &"all_monsters",
			}
	return {}


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
	for dice_body in spawned_dice:
		if dice_body == null:
			continue
		dice_body.linear_velocity.y *= POST_BATTLE_REWARD_DICE_THROW_HEIGHT_MULTIPLIER
	_has_spawned_post_battle_reward_dice = true


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
	var target_kind := StringName(target_descriptor.get("kind", &""))
	if target_kind == &"player":
		return _player_sprite.global_position + Vector3.UP * ACTIVATION_TARGET_LIFT_Y
	if target_kind == &"monster":
		var monster_index := int(target_descriptor.get("index", -1))
		for monster_state in _monster_sprite_states:
			if int(monster_state.get("index", -1)) == monster_index:
				var sprite := monster_state.get("sprite") as MeshInstance3D
				return sprite.global_position + Vector3.UP * ACTIVATION_TARGET_LIFT_Y
	if target_kind == &"all_monsters":
		var living_monster_positions: Array[Vector3] = []
		for monster_state in _monster_sprite_states:
			var monster_index := int(monster_state.get("index", -1))
			if not battle_room_data.can_target_monster(monster_index):
				continue
			var sprite := monster_state.get("sprite") as MeshInstance3D
			living_monster_positions.append(sprite.global_position)
		if not living_monster_positions.is_empty():
			var center := Vector3.ZERO
			for position in living_monster_positions:
				center += position
			center /= float(living_monster_positions.size())
			return center + Vector3.UP * ACTIVATION_TARGET_LIFT_Y
	return base_origin + Vector3.UP * SELECTED_FRAME_LIFT_Y


func _initialize_battle_state() -> void:
	if battle_room_data == null:
		return
	if battle_room_data.battle_status == &"not_started":
		_has_spawned_post_battle_reward_dice = false
		_is_waiting_post_battle_reward_dice = false
		battle_room_data.start_battle()
	_start_current_turn()


func _start_current_turn() -> void:
	if battle_room_data == null:
		return
	_clear_board_dice()
	if battle_room_data.is_battle_over():
		_handle_post_battle_reward_dice()
		_update_turn_ui()
		return
	_throw_current_turn_dice()
	_update_turn_ui()
	if battle_room_data.is_monster_turn():
		_run_current_monster_turn()


func _throw_current_turn_dice() -> void:
	if _board == null or battle_room_data == null:
		return
	var requests: Array[DiceThrowRequest] = []
	if battle_room_data.is_player_turn() and battle_room_data.player_instance != null:
		for dice_definition in battle_room_data.player_instance.dice_loadout:
			if dice_definition == null:
				continue
			requests.append(_build_dice_throw_request(dice_definition, {"owner": &"player"}))
	elif battle_room_data.is_monster_turn() and battle_room_data.can_target_monster(battle_room_data.current_monster_turn_index):
		var monster_view := battle_room_data.monster_views[battle_room_data.current_monster_turn_index]
		for _index in range(monster_view.dice_count):
			requests.append(_build_dice_throw_request(null, {
				"owner": &"monster",
				"monster_index": battle_room_data.current_monster_turn_index,
			}))
	if not requests.is_empty():
		_board.throw_dice(requests)


func _build_dice_throw_request(dice_definition: DiceDefinition, metadata: Dictionary) -> DiceThrowRequest:
	var request := DiceThrowRequestScript.create(BASE_DICE_SCENE, Vector3.ZERO, 1.0, Vector3.ONE, metadata)
	if dice_definition != null:
		request.metadata["definition"] = dice_definition
	return request


func _clear_board_dice() -> void:
	for dice in _get_board_dice():
		if not is_instance_valid(dice):
			continue
		if dice.get_parent() != null:
			dice.get_parent().remove_child(dice)
		dice.queue_free()


func _get_turn_dice(owner: StringName, monster_index: int = -1) -> Array[Dice]:
	var owned_dice: Array[Dice] = []
	for dice in _get_board_dice():
		if StringName(dice.get_meta(&"owner", &"")) != owner:
			continue
		if owner == &"monster" and int(dice.get_meta(&"monster_index", -1)) != monster_index:
			continue
		owned_dice.append(dice)
	return owned_dice


func _are_current_monster_turn_dice_stopped() -> bool:
	if battle_room_data == null or not battle_room_data.is_monster_turn():
		return true
	var monster_dice := _get_turn_dice(&"monster", battle_room_data.current_monster_turn_index)
	if monster_dice.is_empty():
		return true
	for dice in monster_dice:
		if not BattleAbilityRuntime.is_die_fully_stopped(dice):
			return false
	return true


func _on_end_turn_button_pressed() -> void:
	if battle_room_data == null or not battle_room_data.is_player_turn() or battle_room_data.is_battle_over():
		return
	_cancel_selected_ability()
	_advance_to_next_turn()


func _on_event_button_pressed() -> void:
	var result := get_tree().change_scene_to_file(EVENT_ROOM_SCENE_PATH)
	if result != OK:
		push_warning("Failed to open event room scene: %s" % EVENT_ROOM_SCENE_PATH)


func _advance_to_next_turn() -> void:
	if battle_room_data == null or _turn_transition_in_progress:
		return
	_turn_transition_in_progress = true
	battle_room_data.advance_turn()
	_start_current_turn()
	_turn_transition_in_progress = false


func _run_current_monster_turn() -> void:
	if battle_room_data == null or not battle_room_data.is_monster_turn() or battle_room_data.is_battle_over():
		return
	var current_monster_index := battle_room_data.current_monster_turn_index
	await MonsterTurnRuntime.run_turn(self, {
		"battle_room": battle_room_data,
		"monster_index": current_monster_index,
		"provide_turn_dice": func() -> Array[Dice]:
			return _get_turn_dice(&"monster", current_monster_index),
		"are_turn_dice_stopped": func() -> bool:
			return _are_current_monster_turn_dice_stopped(),
		"execute_ability": func(monster_index: int, ability: AbilityDefinition, target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> void:
			await _execute_monster_ability(monster_index, ability, target_descriptor, consumed_dice),
	})
	if battle_room_data == null or not is_inside_tree() or not battle_room_data.is_monster_turn() or battle_room_data.is_battle_over():
		return
	_advance_to_next_turn()


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
	var mouse_position := get_viewport().get_mouse_position()
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_direction := _camera.project_ray_normal(mouse_position)
	var denominator := ray_direction.y
	if absf(denominator) < 0.0001:
		return Vector3(ray_origin.x, plane_y, ray_origin.z)
	var distance := (plane_y - ray_origin.y) / denominator
	if distance < 0.0:
		distance = 0.0
	var hit_position := ray_origin + ray_direction * distance
	hit_position.y = plane_y
	return hit_position


func _screen_point_hits_mesh(mesh_instance: MeshInstance3D, screen_point: Vector2) -> bool:
	if mesh_instance == null or not is_instance_valid(mesh_instance) or not mesh_instance.visible:
		return false
	if mesh_instance.mesh == null:
		return false
	var projected_rect := _project_mesh_screen_rect(mesh_instance)
	return projected_rect.size.x > 0.0 and projected_rect.size.y > 0.0 and projected_rect.has_point(screen_point)


func _project_mesh_screen_rect(mesh_instance: MeshInstance3D) -> Rect2:
	var aabb := mesh_instance.mesh.get_aabb()
	var corners := [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for corner in corners:
		var projected := _camera.unproject_position(mesh_instance.to_global(corner))
		min_point.x = minf(min_point.x, projected.x)
		min_point.y = minf(min_point.y, projected.y)
		max_point.x = maxf(max_point.x, projected.x)
		max_point.y = maxf(max_point.y, projected.y)
	return Rect2(min_point, max_point - min_point)
