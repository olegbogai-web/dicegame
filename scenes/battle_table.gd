extends Node3D

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")
const BattleControllerScript = preload("res://content/combat/battle_controller.gd")
const BoardControllerScript = preload("res://ui/scripts/board_controller.gd")
const Dice = preload("res://content/dice/dice.gd")
const TEST_MONSTER_DEFINITION := preload("res://content/monsters/definitions/test_monster.tres")

const SLOT_EMPTY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const SLOT_ASSIGNED_COLOR := Color(0.82, 0.9, 1.0, 1.0)
const SLOT_READY_COLOR := Color(0.2, 0.62, 1.0, 1.0)
const SLOT_HIGHLIGHT_COLOR := Color(0.36, 0.9, 0.48, 1.0)
const FRAME_READY_COLOR := Color(0.12, 0.55, 1.0, 1.0)
const TINT_MATERIAL_META_KEY := &"runtime_tint_material"
const MAX_LOG_LINES := 10

@onready var _camera: Camera3D = $Camera3D
@onready var _board: BoardController = $board
@onready var _left_floor: MeshInstance3D = $left_floor
@onready var _right_floor: MeshInstance3D = $right_floor
@onready var _player_sprite: MeshInstance3D = $player_sprite
@onready var _monster_sprite_template: MeshInstance3D = $monster_sprite
@onready var _player_ability_template: MeshInstance3D = $ability_frame
@onready var _monster_ability_template: MeshInstance3D = $ability_frame2
@onready var _battle_status_label: Label = %BattleStatusLabel
@onready var _turn_status_label: Label = %TurnStatusLabel
@onready var _player_abilities_box: VBoxContainer = %PlayerAbilitiesBox
@onready var _targets_box: VBoxContainer = %TargetsBox
@onready var _battle_log_label: Label = %BattleLogLabel

const HEALTH_BAR_META_KEY := &"health_bar_base_transform"

var battle_room_data: BattleRoom
var _generated_monster_sprites: Array[Node] = []
var _generated_player_ability_frames: Array[Node] = []
var _generated_monster_ability_frames: Array[Node] = []
var _player_ability_slot_states: Array[Dictionary] = []
var _battle_controller: BattleController
var _battle_log_lines: Array[String] = []
var _pending_ability: AbilityDefinition
var _monster_definitions: Array[MonsterDefinition] = [TEST_MONSTER_DEFINITION]
var _last_player_ability_signature := ""


func _ready() -> void:
	set_physics_process(true)
	if battle_room_data == null:
		configure_from_battle_room(BattleRoomScript.create_test_battle_room())
	else:
		_apply_room_data()
	_setup_board_signals()
	_setup_battle_controller()
	_reset_battle_ui()


func configure_from_battle_room(next_battle_room: BattleRoom) -> void:
	battle_room_data = next_battle_room
	if is_node_ready():
		_apply_room_data()


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


func set_monsters(monster_definitions: Array[MonsterDefinition]) -> void:
	_monster_definitions = monster_definitions.duplicate()
	_ensure_battle_room_data()
	battle_room_data.set_monsters_from_definitions(monster_definitions)
	if is_node_ready():
		_apply_room_data()


func _ensure_battle_room_data() -> void:
	if battle_room_data == null:
		battle_room_data = BattleRoomScript.new()


func _apply_room_data() -> void:
	if battle_room_data == null:
		return
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
	_apply_ability_frames(
		battle_room_data.get_monster_abilities(),
		_monster_ability_template,
		_generated_monster_ability_frames
	)
	_refresh_player_ability_snap_state()
	_last_player_ability_signature = ""
	_rebuild_player_ability_buttons()
	_update_turn_status_label()


func _apply_floor_textures() -> void:
	_apply_texture_to_mesh(_left_floor, battle_room_data.left_floor_texture)
	_apply_texture_to_mesh(_right_floor, battle_room_data.right_floor_texture)


func _apply_player_sprite() -> void:
	var player_view := battle_room_data.player_view
	_player_sprite.visible = player_view != null and player_view.sprite != null
	if not _player_sprite.visible:
		return
	_apply_texture_to_mesh(_player_sprite, player_view.sprite)
	_player_sprite.transform = Transform3D(Basis.from_scale(player_view.base_scale), BattleRoomScript.PLAYER_SPRITE_POSITION)
	_apply_health_bar(_player_sprite, battle_room_data.get_player_health_ratio())


func _apply_monster_sprites() -> void:
	_clear_generated_nodes(_generated_monster_sprites)

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
			_register_player_ability_slots(frame, ability, index)


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
	if combatant_sprite == null:
		return

	var health_bar := combatant_sprite.get_node_or_null(^"HP_frame/HP_bar_player") as MeshInstance3D
	if health_bar == null:
		health_bar = combatant_sprite.get_node_or_null(^"HP_frame_monster/HP_bar_monster") as MeshInstance3D
	if health_bar == null:
		return

	var resolved_ratio := clampf(health_ratio, 0.0, 1.0)
	if not health_bar.has_meta(HEALTH_BAR_META_KEY):
		health_bar.set_meta(HEALTH_BAR_META_KEY, health_bar.transform)

	var base_transform: Transform3D = health_bar.get_meta(HEALTH_BAR_META_KEY)
	var base_scale := base_transform.basis.get_scale()
	var target_scale_x := base_scale.x * resolved_ratio
	health_bar.visible = not is_zero_approx(target_scale_x)
	if not health_bar.visible:
		return

	var target_basis := Basis.from_scale(Vector3(target_scale_x, base_scale.y, base_scale.z))
	var target_origin := base_transform.origin
	target_origin.x = base_transform.origin.x - (base_scale.x - target_scale_x) * 0.5
	health_bar.transform = Transform3D(target_basis, target_origin)


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


func _physics_process(_delta: float) -> void:
	_refresh_player_ability_snap_state()
	_sync_player_dice_with_battle_state()
	_rebuild_player_ability_buttons()


func _refresh_player_ability_snap_state() -> void:
	if _player_ability_slot_states.is_empty():
		return

	var dice_list := _get_board_dice()
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

		var candidate := _find_snap_candidate(slot_state, dice_list, used_dice)
		if candidate == null:
			continue
		used_dice[candidate.get_instance_id()] = true
		candidate.assign_ability_slot(slot_state["slot_id"], _get_slot_target_position(slot_state["dice_place"], candidate))

	_update_player_ability_visuals(dice_list)


func _register_player_ability_slots(frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	var dice_places := _get_dice_place_nodes(frame)
	var slot_conditions := _build_slot_conditions(ability)
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


func _build_slot_conditions(ability: AbilityDefinition) -> Array[AbilityDiceCondition]:
	var conditions: Array[AbilityDiceCondition] = []
	if ability == null or ability.cost == null:
		return conditions
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		for _count in maxi(dice_condition.required_count, 0):
			conditions.append(dice_condition)
	return conditions


func _get_board_dice() -> Array[Dice]:
	return _board.get_board_dice() if _board != null else []


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

	return _dice_satisfies_use_conditions(dice, slot_state.get("ability") as AbilityDefinition)


func _dice_satisfies_use_conditions(dice: Dice, ability: AbilityDefinition) -> bool:
	if dice == null or ability == null:
		return false

	for condition in ability.use_conditions:
		if condition == null:
			continue
		if condition.predicate == &"selected_die_top_face_parity":
			var parity := String(condition.parameters.get("parity", ""))
			var top_face_value := dice.get_top_face_value()
			if parity == "even" and top_face_value % 2 != 0:
				return false
			if parity == "odd" and top_face_value % 2 == 0:
				return false

	return true


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
		_set_mesh_tint(slot_info["frame"], FRAME_READY_COLOR if slot_info["ready"] else SLOT_EMPTY_COLOR)


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
	var material := mesh_instance.get_meta(TINT_MATERIAL_META_KEY, null) as StandardMaterial3D
	if material == null:
		if mesh_instance.material_override is StandardMaterial3D:
			material = (mesh_instance.material_override as StandardMaterial3D).duplicate()
		else:
			material = StandardMaterial3D.new()
		mesh_instance.set_meta(TINT_MATERIAL_META_KEY, material)
		mesh_instance.material_override = material
	material.albedo_color = color


func _setup_board_signals() -> void:
	if _board == null:
		return
	if not _board.throw_button_pressed.is_connected(_on_board_throw_button_pressed):
		_board.throw_button_pressed.connect(_on_board_throw_button_pressed)
	if not _board.start_test_battle_pressed.is_connected(_on_start_test_battle_pressed):
		_board.start_test_battle_pressed.connect(_on_start_test_battle_pressed)
	if not _board.end_turn_pressed.is_connected(_on_end_turn_pressed):
		_board.end_turn_pressed.connect(_on_end_turn_pressed)


func _setup_battle_controller() -> void:
	_battle_controller = BattleControllerScript.new()
	_battle_controller.log_emitted.connect(_append_battle_log)
	_battle_controller.player_dice_requested.connect(_on_player_dice_requested)
	_battle_controller.player_action_required.connect(_on_player_action_required)
	_battle_controller.battle_state_changed.connect(_on_battle_state_changed)
	_battle_controller.battle_ended.connect(_on_battle_ended)
	_battle_controller.turn_started.connect(_on_turn_started)


func _reset_battle_ui() -> void:
	_pending_ability = null
	_clear_container_children(_targets_box)
	if _battle_status_label != null:
		_battle_status_label.text = 'Нажмите "Начать тестовый бой".'
	if _turn_status_label != null:
		_turn_status_label.text = "Бой не активен."
	if _battle_log_label != null:
		_battle_log_label.text = ""
	if _board != null:
		_board.set_end_turn_enabled(false)
	_rebuild_player_ability_buttons()


func _on_board_throw_button_pressed() -> void:
	if _is_battle_active():
		_append_battle_log("Во время боя кубы бросаются автоматически в начале хода игрока.")
		return

	_board.throw_single_default_die()


func _on_start_test_battle_pressed() -> void:
	_start_test_battle()


func _on_end_turn_pressed() -> void:
	if not _is_player_turn():
		_append_battle_log("Закончить ход можно только во время хода игрока.")
		return
	_clear_pending_target_selection()
	if _board != null:
		_board.clear_board_dice()
	_battle_controller.end_player_turn()


func _start_test_battle() -> void:
	var room := BattleRoomScript.create_test_battle_room()
	configure_from_battle_room(room)
	_monster_definitions = [TEST_MONSTER_DEFINITION]
	_battle_log_lines.clear()
	if _battle_log_label != null:
		_battle_log_label.text = ""
	_pending_ability = null
	_clear_container_children(_targets_box)
	if _board != null:
		_board.clear_board_dice()
	_battle_controller.setup_battle(room.player_instance, room.player_view.sprite, _monster_definitions)
	_battle_controller.start_battle()


func _on_player_dice_requested(dice_count: int) -> void:
	if _board == null:
		return
	_board.clear_board_dice()
	_board.throw_default_dice(dice_count)
	_board.set_end_turn_enabled(true)
	_append_battle_log("Игрок получил %d куб(а/ов) на ход." % dice_count)


func _on_player_action_required(_combatant: CombatantState, _turn_state: TurnState) -> void:
	if _board != null:
		_board.set_end_turn_enabled(true)
	_rebuild_player_ability_buttons()


func _on_turn_started(combatant: CombatantState, _turn_state: TurnState) -> void:
	if _turn_status_label == null:
		return
	if combatant.is_player():
		_turn_status_label.text = "Ход игрока: разложите кубы по слотам, затем активируйте способность."
	else:
		_turn_status_label.text = "Ход монстра: %s." % combatant.display_name


func _on_battle_state_changed(state: BattleState) -> void:
	_update_battle_room_from_state(state)
	_apply_room_data()
	_update_battle_status_label(state)
	_update_turn_status_label()
	_rebuild_player_ability_buttons()


func _on_battle_ended(result_code: StringName, _state: BattleState) -> void:
	if _board != null:
		_board.set_end_turn_enabled(false)
		_board.clear_board_dice()
	_clear_pending_target_selection()
	if result_code == &"player_victory":
		_battle_status_label.text = "Тестовый бой завершен: победа игрока."
	else:
		_battle_status_label.text = "Тестовый бой завершен: поражение игрока."


func _append_battle_log(message: String) -> void:
	if message.is_empty():
		return
	_battle_log_lines.append(message)
	while _battle_log_lines.size() > MAX_LOG_LINES:
		_battle_log_lines.remove_at(0)
	if _battle_log_label != null:
		_battle_log_label.text = "\n".join(_battle_log_lines)


func _sync_player_dice_with_battle_state() -> void:
	if not _is_player_turn():
		return
	if _battle_controller == null:
		return
	_battle_controller.sync_player_dice(_build_player_dice_entries())


func _build_player_dice_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for dice in _get_board_dice():
		var top_face := dice.get_top_face()
		entries.append({
			"id": StringName(str(dice.get_instance_id())),
			"value": dice.get_top_face_value(),
			"tags": dice.get_match_tags(),
			"face_id": StringName(top_face.text_value if top_face != null else ""),
		})
	return entries


func _rebuild_player_ability_buttons() -> void:
	if _player_abilities_box == null or battle_room_data == null:
		return

	var signature := _build_player_ability_signature()
	if signature == _last_player_ability_signature:
		return
	_last_player_ability_signature = signature

	_clear_container_children(_player_abilities_box)
	var player_turn_active := _is_player_turn()
	for ability in battle_room_data.get_player_abilities():
		if ability == null:
			continue
		var button := Button.new()
		button.text = _build_ability_button_text(ability)
		button.disabled = not player_turn_active or not _can_activate_ability_from_ui(ability)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_player_ability_pressed.bind(ability))
		_player_abilities_box.add_child(button)




func _build_player_ability_signature() -> String:
	var parts: Array[String] = ["player_turn=%s" % str(_is_player_turn())]
	for ability in battle_room_data.get_player_abilities():
		if ability == null:
			continue
		var selected_ids := _collect_selected_dice_ids_for_ability(ability)
		selected_ids.sort()
		var selected_texts: Array[String] = []
		for selected_id in selected_ids:
			selected_texts.append(String(selected_id))
		parts.append("%s:%s" % [ability.ability_id, ",".join(selected_texts)])
	return "|".join(parts)


func _build_ability_button_text(ability: AbilityDefinition) -> String:
	var required_slots := battle_room_data.get_required_dice_slots(ability)
	var selected_dice_ids := _collect_selected_dice_ids_for_ability(ability)
	var suffix := ""
	if required_slots > 0:
		suffix = " [%d/%d кубов]" % [selected_dice_ids.size(), required_slots]
	return "%s%s\n%s" % [ability.display_name, suffix, ability.description]


func _on_player_ability_pressed(ability: AbilityDefinition) -> void:
	if not _is_player_turn():
		return
	if ability == null:
		return
	if not _can_activate_ability_from_ui(ability):
		_append_battle_log("Способность пока нельзя применить: проверьте выбранные кубы и цель.")
		return

	_pending_ability = ability
	var target_rule := ability.target_rule
	if target_rule == null or target_rule.selection == AbilityTargetRule.Selection.NONE:
		_try_activate_pending_ability(&"player")
		return
	if target_rule.allow_self and (target_rule.max_targets == 0 or target_rule.selection == AbilityTargetRule.Selection.NONE):
		_try_activate_pending_ability(&"player")
		return
	_build_target_buttons_for_ability(ability)


func _build_target_buttons_for_ability(ability: AbilityDefinition) -> void:
	_clear_container_children(_targets_box)
	if ability == null or _battle_controller == null or _battle_controller.battle_state == null:
		return

	if ability.target_rule != null and ability.target_rule.allow_self:
		var self_button := Button.new()
		self_button.text = "Выбрать себя"
		self_button.pressed.connect(_try_activate_pending_ability.bind(&"player"))
		_targets_box.add_child(self_button)

	for enemy in _battle_controller.battle_state.get_alive_enemies():
		var button := Button.new()
		button.text = enemy.display_name
		button.pressed.connect(_try_activate_pending_ability.bind(enemy.combatant_id))
		_targets_box.add_child(button)


func _try_activate_pending_ability(target_id: StringName) -> void:
	if _pending_ability == null:
		return
	var selected_dice_ids := _collect_selected_dice_ids_for_ability(_pending_ability)
	var response := _battle_controller.activate_player_ability(_pending_ability, target_id, selected_dice_ids)
	if not response["success"]:
		_append_battle_log(String(response["message"]))
		return
	var consumed_dice_ids: Array[StringName] = response["consumed_dice_ids"]
	_remove_consumed_dice(consumed_dice_ids)
	_clear_pending_target_selection()


func _collect_selected_dice_ids_for_ability(ability: AbilityDefinition) -> Array[StringName]:
	var selected_ids: Array[StringName] = []
	for slot_state in _player_ability_slot_states:
		if slot_state.get("ability") != ability:
			continue
		var assigned_dice := _find_dice_for_slot(slot_state, _get_board_dice())
		if assigned_dice == null or not assigned_dice.is_snapped_to_ability_slot():
			continue
		selected_ids.append(StringName(str(assigned_dice.get_instance_id())))
	return selected_ids


func _remove_consumed_dice(consumed_dice_ids: Array[StringName]) -> void:
	var consumed_lookup := {}
	for consumed_id in consumed_dice_ids:
		consumed_lookup[String(consumed_id)] = true
	for dice in _get_board_dice():
		if consumed_lookup.has(str(dice.get_instance_id())):
			dice.queue_free()


func _can_activate_ability_from_ui(ability: AbilityDefinition) -> bool:
	if not _is_player_turn() or ability == null or _battle_controller == null:
		return false
	var selected_dice_ids := _collect_selected_dice_ids_for_ability(ability)
	if ability.cost != null and ability.cost.requires_dice():
		return _battle_controller.can_activate_ability(_battle_controller.get_active_combatant(), ability, selected_dice_ids)
	return true


func _clear_pending_target_selection() -> void:
	_pending_ability = null
	_clear_container_children(_targets_box)


func _clear_container_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _update_battle_room_from_state(state: BattleState) -> void:
	if state == null or battle_room_data == null:
		return
	var player := state.get_player()
	if player != null and battle_room_data.player_view != null:
		battle_room_data.player_view.current_hp = player.current_hp
		battle_room_data.player_view.max_hp = player.max_hp

	for monster_view in battle_room_data.monster_views:
		monster_view.current_hp = 0
	for enemy in state.get_alive_enemies():
		if enemy.spawn_index >= 0 and enemy.spawn_index < battle_room_data.monster_views.size():
			battle_room_data.monster_views[enemy.spawn_index].current_hp = enemy.current_hp
			battle_room_data.monster_views[enemy.spawn_index].max_hp = enemy.max_hp
	for combatant in state.combatants:
		if combatant.side != CombatantState.Side.ENEMY:
			continue
		if combatant.spawn_index >= 0 and combatant.spawn_index < battle_room_data.monster_views.size():
			battle_room_data.monster_views[combatant.spawn_index].current_hp = combatant.current_hp
			battle_room_data.monster_views[combatant.spawn_index].max_hp = combatant.max_hp


func _update_battle_status_label(state: BattleState) -> void:
	if _battle_status_label == null:
		return
	if state == null:
		_battle_status_label.text = 'Нажмите "Начать тестовый бой".'
		return
	var enemies_alive := state.get_alive_enemies().size()
	_battle_status_label.text = "Раунд %d. Игрок HP: %d/%d. Живых монстров: %d." % [
		state.round_index,
		battle_room_data.player_view.current_hp,
		battle_room_data.player_view.max_hp,
		enemies_alive,
	]
	if state.is_finished:
		_battle_status_label.text += " Итог: %s." % ("победа" if state.result_code == &"player_victory" else "поражение")


func _update_turn_status_label() -> void:
	if _turn_status_label == null:
		return
	if _battle_controller == null or _battle_controller.battle_state == null or _battle_controller.battle_state.is_finished:
		if _battle_controller != null and _battle_controller.battle_state != null and _battle_controller.battle_state.is_finished:
			_turn_status_label.text = "Бой завершен. Можно начать новый тестовый бой."
		return
	var active_combatant := _battle_controller.get_active_combatant()
	if active_combatant == null:
		_turn_status_label.text = "Ожидание начала боя."
		return
	if active_combatant.is_player():
		_turn_status_label.text = "Ход игрока. Перетащите кубы в слоты и выберите способность."
	else:
		_turn_status_label.text = "Ход монстра: %s." % active_combatant.display_name


func _is_battle_active() -> bool:
	return _battle_controller != null and _battle_controller.battle_state != null and not _battle_controller.battle_state.is_finished


func _is_player_turn() -> bool:
	if not _is_battle_active():
		return false
	var active_combatant := _battle_controller.get_active_combatant()
	return active_combatant != null and active_combatant.is_player()
