extends RefCounted
class_name BattleActionOrchestrator

const Dice = preload("res://content/dice/dice.gd")
const BattleActivationAnimationRuntime = preload("res://content/combat/runtime/battle_activation_animation_runtime.gd")
const MONSTER_PRE_ACTIVATE_DELAY_SEC := 0.3


func _activate_selected_ability(owner: Node, target_descriptor: Dictionary) -> void:
	if owner._selected_ability_state.is_empty():
		return
	if not owner._is_ability_state_ready(owner._selected_ability_state):
		owner._cancel_selected_ability()
		return

	var frame_state = owner._selected_ability_state.duplicate(true)
	var consumed_dice = owner._collect_ready_dice_for_frame(frame_state.get("frame") as MeshInstance3D)
	owner._selected_ability_state.clear()
	await _play_ability_use_visual(owner, frame_state, target_descriptor, consumed_dice)
	owner._refresh_player_ability_snap_state()


func _play_ability_use_visual(
	owner: Node,
	frame_state: Dictionary,
	target_descriptor: Dictionary,
	consumed_dice: Array[Dice],
	pre_activate_delay_sec: float = 0.0
) -> void:
	var frame := frame_state.get("frame") as MeshInstance3D
	var ability := frame_state.get("ability") as AbilityDefinition
	if frame == null or ability == null:
		return
	var base_origin: Vector3 = frame_state.get("base_origin", frame.transform.origin)
	var target_origin = owner._resolve_activation_target_origin(target_descriptor, base_origin)
	var dice_assignments := _build_dice_assignments_for_frame(owner, consumed_dice, frame_state)
	var on_activate := func() -> void:
		var runtime_target_descriptor := target_descriptor.duplicate(true)
		runtime_target_descriptor["consumed_dice"] = consumed_dice
		runtime_target_descriptor["available_player_dice"] = _collect_available_player_dice(owner)
		owner.battle_room_data.activate_current_turn_ability(ability, runtime_target_descriptor)
		_apply_combatant_views_after_ability_resolution(owner)
	var on_finished := func() -> void:
		owner._activation_in_progress = false
		owner._update_turn_ui()
	owner._activation_in_progress = true
	await BattleActivationAnimationRuntime.play_ability_use_animation(
		owner,
		frame,
		base_origin,
		target_origin,
		consumed_dice,
		dice_assignments,
		owner.ACTIVATION_ANIMATION_DURATION,
		owner._player_ability_input_controller.SELECTED_FRAME_LIFT_Y,
		pre_activate_delay_sec,
		on_activate,
		on_finished
	)


func _build_dice_assignments_for_frame(owner: Node, consumed_dice: Array[Dice], frame_state: Dictionary) -> Array[Dictionary]:
	var dice_assignments: Array[Dictionary] = []
	var dice_places: Array[MeshInstance3D] = []
	var raw_dice_places := frame_state.get("dice_places", []) as Array
	for dice_place in raw_dice_places:
		if dice_place is MeshInstance3D:
			dice_places.append(dice_place as MeshInstance3D)
	if dice_places.is_empty():
		var frame := frame_state.get("frame") as MeshInstance3D
		dice_places = owner._get_dice_place_nodes(frame)
	for index in mini(consumed_dice.size(), dice_places.size()):
		var dice := consumed_dice[index]
		var dice_place := dice_places[index]
		if dice == null or dice_place == null:
			continue
		dice_assignments.append({
			"dice": dice,
			"target_position": owner._player_ability_input_controller._get_slot_target_position(dice_place, dice),
		})
	return dice_assignments


func _find_monster_ability_frame_state(owner: Node, monster_index: int, ability: AbilityDefinition) -> Dictionary:
	var fallback_match := {}
	for frame_state in owner._monster_ability_frame_states:
		if frame_state.get("ability") != ability:
			continue
		if int(frame_state.get("monster_index", -1)) == monster_index:
			return frame_state
		var shared_monster_indexes := frame_state.get("monster_indexes", PackedInt32Array()) as PackedInt32Array
		if shared_monster_indexes.has(monster_index):
			return frame_state
		if fallback_match.is_empty():
			fallback_match = frame_state
	return fallback_match


func _execute_monster_ability(
	owner: Node,
	monster_index: int,
	ability: AbilityDefinition,
	target_descriptor: Dictionary,
	consumed_dice: Array[Dice]
) -> void:
	var frame_state := _find_monster_ability_frame_state(owner, monster_index, ability)
	if frame_state.is_empty():
		var runtime_target_descriptor := target_descriptor.duplicate(true)
		runtime_target_descriptor["consumed_dice"] = consumed_dice
		runtime_target_descriptor["available_player_dice"] = _collect_available_player_dice(owner)
		owner.battle_room_data.activate_current_turn_ability(ability, runtime_target_descriptor)
		_apply_combatant_views_after_ability_resolution(owner)
		for dice in consumed_dice:
			if is_instance_valid(dice):
				dice.queue_free()
		return
	await _play_ability_use_visual(owner, frame_state, target_descriptor, consumed_dice, MONSTER_PRE_ACTIVATE_DELAY_SEC)


func _collect_available_player_dice(owner: Node) -> Array[Dice]:
	var available: Array[Dice] = []
	if owner == null or owner._board == null:
		return available
	for child in owner._board.get_children():
		if child is Dice and is_instance_valid(child) and StringName((child as Dice).get_meta(&"owner", &"")) == &"player":
			available.append(child as Dice)
	return available


func _apply_combatant_views_after_ability_resolution(owner: Node) -> void:
	owner._apply_player_sprite()
	owner._apply_monster_sprites()
	owner._update_turn_ui()
	if owner.battle_room_data != null and owner.battle_room_data.is_battle_over():
		print("[Debug][RewardFlow] Бой завершен. Статус: %s" % String(owner.battle_room_data.battle_status))
		owner._clear_board_dice()
		owner._handle_post_battle_reward_dice()
