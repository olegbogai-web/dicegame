extends RefCounted
class_name PlayerAbilityInputController

const Dice = preload("res://content/dice/dice.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")

const SLOT_EMPTY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const SLOT_ASSIGNED_COLOR := Color(0.82, 0.9, 1.0, 1.0)
const SLOT_READY_COLOR := Color(0.2, 0.62, 1.0, 1.0)
const SLOT_HIGHLIGHT_COLOR := Color(0.36, 0.9, 0.48, 1.0)
const FRAME_READY_COLOR := Color(0.12, 0.55, 1.0, 1.0)
const FRAME_SELECTED_COLOR := Color(1.0, 0.92, 0.52, 1.0)
const SELECTED_FRAME_LIFT_Y := 1.9
const SELECTED_FRAME_MOUSE_FOLLOW_FACTOR := 0.2


func handle_unhandled_input(owner: Node, event: InputEvent, ctx: Dictionary) -> bool:
	if Engine.is_editor_hint() or bool(ctx.get("activation_in_progress", false)) or bool(ctx.get("turn_transition_in_progress", false)):
		return false
	var battle_room: BattleRoom = owner.battle_room_data
	if battle_room == null:
		return false
	if event is InputEventMouseButton and not event.pressed:
		return false

	if bool(ctx.get("awaiting_reward_selection", false)) and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var resolve_reward_click := ctx.get("resolve_reward_click") as Callable
		var select_reward := ctx.get("select_reward") as Callable
		if resolve_reward_click.is_valid() and select_reward.is_valid():
			var reward_click := resolve_reward_click.call((event as InputEventMouseButton).position)
			if not reward_click.is_empty():
				select_reward.call(reward_click)
				return true

	if not battle_room.is_player_turn() or battle_room.is_battle_over():
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_selected_ability(owner)
		return true

	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return false

	var mouse_event := event as InputEventMouseButton
	var has_player_dice_at_screen_point := ctx.get("has_player_dice_at_screen_point") as Callable
	if has_player_dice_at_screen_point.is_valid() and has_player_dice_at_screen_point.call(mouse_event.position):
		return false

	var clicked_frame_state := find_player_ability_frame_at_screen_point(owner, mouse_event.position)
	if not clicked_frame_state.is_empty() and is_ability_state_ready(owner, clicked_frame_state):
		select_player_ability(owner, clicked_frame_state)
		return true

	if owner._selected_ability_state.is_empty():
		return false

	var resolve_target := ctx.get("resolve_target_descriptor") as Callable
	var activate_selected_ability := ctx.get("activate_selected_ability") as Callable
	if not resolve_target.is_valid() or not activate_selected_ability.is_valid():
		return false
	var target_descriptor := resolve_target.call(owner._selected_ability_state.get("ability") as AbilityDefinition, mouse_event.position)
	if target_descriptor.is_empty():
		return false

	activate_selected_ability.call(target_descriptor)
	return true


func refresh_player_ability_snap_state(owner: Node) -> void:
	if owner._player_ability_slot_states.is_empty():
		return

	var dice_list := get_board_dice(owner)
	if owner.battle_room_data == null or not owner.battle_room_data.is_player_turn() or owner.battle_room_data.is_battle_over():
		for dice in dice_list:
			if dice.get_assigned_ability_slot_id() != &"":
				dice.clear_ability_slot()
		update_player_ability_visuals(owner, [])
		return

	var slot_by_id := {}
	for slot_state in owner._player_ability_slot_states:
		slot_by_id[slot_state["slot_id"]] = slot_state

	for dice in dice_list:
		var assigned_slot_id := dice.get_assigned_ability_slot_id()
		if assigned_slot_id == &"":
			continue
		if not slot_by_id.has(assigned_slot_id):
			dice.clear_ability_slot()
			continue
		var assigned_slot: Dictionary = slot_by_id[assigned_slot_id]
		if not dice_matches_slot(dice, assigned_slot):
			dice.clear_ability_slot()

	var used_dice := {}
	for slot_state in owner._player_ability_slot_states:
		var assigned_dice := find_dice_for_slot(slot_state, dice_list)
		if assigned_dice != null:
			used_dice[assigned_dice.get_instance_id()] = true
			var target_position := get_slot_target_position(slot_state["dice_place"], assigned_dice)
			assigned_dice.assign_ability_slot(slot_state["slot_id"], target_position)
			continue
		if not is_player_ability_frame_at_base(owner, slot_state["frame"] as MeshInstance3D):
			continue

		var candidate := find_snap_candidate(owner, slot_state, dice_list, used_dice)
		if candidate == null:
			continue
		used_dice[candidate.get_instance_id()] = true
		candidate.assign_ability_slot(slot_state["slot_id"], get_slot_target_position(slot_state["dice_place"], candidate))

	update_player_ability_visuals(owner, dice_list)


func is_player_ability_frame_at_base(owner: Node, frame: MeshInstance3D) -> bool:
	if frame == null:
		return false
	for frame_state in owner._player_ability_frame_states:
		if frame_state.get("frame") != frame:
			continue
		var base_origin: Vector3 = frame_state.get("base_origin", frame.transform.origin)
		return frame.transform.origin.is_equal_approx(base_origin)
	return true


func register_player_ability_frame(owner: Node, frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	owner._player_ability_frame_states.append({
		"frame": frame,
		"ability": ability,
		"ability_index": ability_index,
		"base_origin": frame.transform.origin,
	})


func register_player_ability_slots(owner: Node, frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int, dice_place_provider: Callable) -> void:
	var dice_places: Array[MeshInstance3D] = []
	if dice_place_provider.is_valid():
		dice_places = dice_place_provider.call(frame)
	var slot_conditions := BattleAbilityRuntime.build_slot_conditions(ability)
	for index in dice_places.size():
		var dice_place := dice_places[index]
		if index >= slot_conditions.size() or not dice_place.visible:
			continue
		owner._player_ability_slot_states.append({
			"slot_id": StringName("player_%s_%d_%d" % [ability.ability_id, ability_index, index]),
			"ability_id": ability.ability_id,
			"ability": ability,
			"frame": frame,
			"dice_place": dice_place,
			"condition": slot_conditions[index],
		})


func find_player_ability_frame_at_screen_point(owner: Node, screen_point: Vector2) -> Dictionary:
	for index in range(owner._player_ability_frame_states.size() - 1, -1, -1):
		var frame_state := owner._player_ability_frame_states[index]
		var frame := frame_state.get("frame") as MeshInstance3D
		if owner._screen_point_hits_mesh(frame, screen_point):
			return frame_state
	return {}


func select_player_ability(owner: Node, frame_state: Dictionary) -> void:
	if frame_state.is_empty():
		return
	if not owner._selected_ability_state.is_empty() and owner._selected_ability_state.get("frame") == frame_state.get("frame"):
		return
	cancel_selected_ability(owner)
	owner._selected_ability_state = frame_state.duplicate()
	var selected_base_origin: Vector3 = frame_state.get("base_origin", Vector3.ZERO)
	owner._selected_mouse_anchor = owner._project_mouse_to_horizontal_plane(selected_base_origin.y)
	update_selected_ability_follow(owner)


func cancel_selected_ability(owner: Node, skip_visual_reset: bool = false) -> void:
	if owner._selected_ability_state.is_empty():
		return
	if not skip_visual_reset:
		var frame := owner._selected_ability_state.get("frame") as MeshInstance3D
		var base_origin: Vector3 = owner._selected_ability_state.get("base_origin", Vector3.ZERO)
		if is_instance_valid(frame):
			frame.transform = Transform3D(frame.transform.basis, base_origin)
	owner._selected_ability_state.clear()
	owner._selected_mouse_anchor = Vector3.ZERO


func update_selected_ability_follow(owner: Node) -> void:
	var frame := owner._selected_ability_state.get("frame") as MeshInstance3D
	if not is_instance_valid(frame):
		owner._selected_ability_state.clear()
		return
	var base_origin: Vector3 = owner._selected_ability_state.get("base_origin", frame.transform.origin)
	var mouse_world := owner._project_mouse_to_horizontal_plane(base_origin.y)
	var mouse_delta := (mouse_world - owner._selected_mouse_anchor) * SELECTED_FRAME_MOUSE_FOLLOW_FACTOR
	var target_origin := base_origin + Vector3(mouse_delta.x, SELECTED_FRAME_LIFT_Y, mouse_delta.z)
	frame.transform = Transform3D(frame.transform.basis, target_origin)


func is_ability_state_ready(owner: Node, frame_state: Dictionary) -> bool:
	var frame := frame_state.get("frame") as MeshInstance3D
	if frame == null:
		return false
	var ability := frame_state.get("ability") as AbilityDefinition
	var consumed_dice := collect_ready_dice_for_frame(owner, frame)
	return BattleAbilityRuntime.can_use_ability_with_dice(ability, consumed_dice, true)


func collect_ready_dice_for_frame(owner: Node, frame: MeshInstance3D) -> Array[Dice]:
	var dice_list := get_board_dice(owner)
	var consumed_dice: Array[Dice] = []
	for slot_state in owner._player_ability_slot_states:
		if slot_state.get("frame") != frame:
			continue
		var assigned_dice := find_dice_for_slot(slot_state, dice_list)
		if assigned_dice != null and assigned_dice.is_snapped_to_ability_slot():
			consumed_dice.append(assigned_dice)
	return consumed_dice


func update_player_ability_visuals(owner: Node, dice_list: Array[Dice]) -> void:
	var active_drag_dice := get_active_drag_dice(dice_list)
	for slot_state in owner._player_ability_slot_states:
		var assigned_dice := find_dice_for_slot(slot_state, dice_list)
		var is_ready := assigned_dice != null and assigned_dice.is_snapped_to_ability_slot()
		var slot_color := SLOT_EMPTY_COLOR
		if should_highlight_slot_for_dice(slot_state, assigned_dice, active_drag_dice):
			slot_color = SLOT_HIGHLIGHT_COLOR
		elif assigned_dice != null:
			slot_color = SLOT_ASSIGNED_COLOR
		if is_ready:
			slot_color = SLOT_READY_COLOR
		owner._set_mesh_tint(slot_state["dice_place"], slot_color)

	for frame_state in owner._player_ability_frame_states:
		var frame := frame_state.get("frame") as MeshInstance3D
		var tint := FRAME_READY_COLOR if is_ability_state_ready(owner, frame_state) else SLOT_EMPTY_COLOR
		if not owner._selected_ability_state.is_empty() and owner._selected_ability_state.get("frame") == frame:
			tint = FRAME_SELECTED_COLOR
		owner._set_mesh_tint(frame, tint)


func get_active_drag_dice(dice_list: Array[Dice]) -> Dice:
	for dice in dice_list:
		if dice.is_being_dragged():
			return dice
	return null


func should_highlight_slot_for_dice(slot_state: Dictionary, assigned_dice: Dice, active_drag_dice: Dice) -> bool:
	if active_drag_dice == null or assigned_dice != null:
		return false
	return dice_matches_slot(active_drag_dice, slot_state)


func dice_matches_slot(dice: Dice, slot_state: Dictionary) -> bool:
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


func get_slot_target_position(dice_place: MeshInstance3D, dice: Dice) -> Vector3:
	var offset_y := 0.1
	if dice != null and dice.definition != null:
		offset_y = dice.definition.get_resolved_size().y * dice.extra_size_multiplier.y * 0.5
	return dice_place.global_position + Vector3.UP * offset_y


func get_board_dice(owner: Node) -> Array[Dice]:
	var dice_list: Array[Dice] = []
	if owner._board == null:
		return dice_list
	for child in owner._board.get_children():
		if child is Dice and is_instance_valid(child):
			dice_list.append(child as Dice)
	return dice_list


func find_dice_for_slot(slot_state: Dictionary, dice_list: Array[Dice]) -> Dice:
	for dice in dice_list:
		if dice.get_assigned_ability_slot_id() == slot_state["slot_id"]:
			return dice
	return null


func find_snap_candidate(owner: Node, slot_state: Dictionary, dice_list: Array[Dice], used_dice: Dictionary) -> Dice:
	var best_candidate: Dice
	var best_distance := INF
	var dice_place := slot_state["dice_place"] as MeshInstance3D
	for dice in dice_list:
		if used_dice.has(dice.get_instance_id()):
			continue
		if dice.is_being_dragged() or dice.get_assigned_ability_slot_id() != &"":
			continue
		if not dice_matches_slot(dice, slot_state):
			continue
		var distance := dice.global_position.distance_to(get_slot_target_position(dice_place, dice))
		if distance > dice.ability_snap_distance or distance >= best_distance:
			continue
		best_distance = distance
		best_candidate = dice
	return best_candidate
