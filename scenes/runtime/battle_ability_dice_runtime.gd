extends RefCounted
class_name BattleAbilityDiceRuntime

const Dice = preload("res://content/dice/dice.gd")

const SNAP_DISTANCE := 0.5
const READY_FRAME_COLOR := Color(0.65, 1.0, 0.65, 1.0)
const DEFAULT_FRAME_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const FILLED_SLOT_COLOR := Color(0.55, 1.0, 0.55, 1.0)
const OPEN_SLOT_COLOR := Color(1.0, 1.0, 1.0, 1.0)

signal frame_ready_state_changed(ability: AbilityDefinition, is_ready: bool)

var _frame_states: Array[Dictionary] = []
var _dice_to_slot: Dictionary = {}
var _tracked_dice: Dictionary = {}
var _dice_tree_exit_callables: Dictionary = {}


func clear() -> void:
	for frame_state in _frame_states:
		var slots: Array = frame_state.get("slots", [])
		for slot_state in slots:
			_release_slot(slot_state)
	_frame_states.clear()

	for dice in _tracked_dice.keys():
		_disconnect_dice_signals(dice)
	_tracked_dice.clear()
	_dice_tree_exit_callables.clear()
	_dice_to_slot.clear()


func register_player_frame(frame: MeshInstance3D, ability: AbilityDefinition, dice_places: Array[MeshInstance3D]) -> void:
	if frame == null or ability == null or dice_places.is_empty():
		return

	var flattened_conditions := _build_slot_conditions(ability)
	if flattened_conditions.is_empty():
		_apply_frame_ready_visual(frame, false)
		return

	var slots: Array[Dictionary] = []
	var active_count := mini(flattened_conditions.size(), dice_places.size())
	for index in active_count:
		slots.append({
			"node": dice_places[index],
			"condition": flattened_conditions[index],
			"assigned_dice": null,
		})
		_apply_slot_visual(dice_places[index], false)

	var frame_state := {
		"frame": frame,
		"ability": ability,
		"slots": slots,
		"is_ready": false,
	}
	_frame_states.append(frame_state)
	_refresh_frame_ready_state(frame_state)


func update(board_root: Node) -> void:
	if board_root == null or _frame_states.is_empty():
		return

	_prune_invalid_assignments()

	var dice_nodes := _collect_board_dice(board_root)
	for dice in dice_nodes:
		_track_dice(dice)

	for dice in dice_nodes:
		if dice == null or _dice_to_slot.has(dice):
			continue
		if dice.is_dragging():
			continue

		var slot_state := _find_best_slot_for_dice(dice)
		if slot_state.is_empty():
			continue
		_assign_dice_to_slot(dice, slot_state)


func is_ability_ready(ability: AbilityDefinition) -> bool:
	for frame_state in _frame_states:
		if frame_state.get("ability") == ability:
			return frame_state.get("is_ready", false)
	return false


func _build_slot_conditions(ability: AbilityDefinition) -> Array[AbilityDiceCondition]:
	var conditions: Array[AbilityDiceCondition] = []
	if ability == null or ability.cost == null:
		return conditions

	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		for _repeat_index in maxi(dice_condition.required_count, 0):
			conditions.append(dice_condition)
	return conditions


func _collect_board_dice(board_root: Node) -> Array[Dice]:
	var dice_nodes: Array[Dice] = []
	for child in board_root.get_children():
		if child is Dice:
			dice_nodes.append(child as Dice)
	return dice_nodes


func _find_best_slot_for_dice(dice: Dice) -> Dictionary:
	var best_slot: Dictionary = {}
	var best_distance := SNAP_DISTANCE
	for frame_state in _frame_states:
		var slots: Array = frame_state.get("slots", [])
		for slot_state in slots:
			if slot_state.get("assigned_dice") != null:
				continue
			if not _dice_matches_condition(dice, slot_state.get("condition") as AbilityDiceCondition):
				continue
			var slot_position := _get_slot_target_position(slot_state.get("node") as MeshInstance3D, dice)
			var distance := dice.global_position.distance_to(slot_position)
			if distance > SNAP_DISTANCE or distance >= best_distance:
				continue
			best_distance = distance
			best_slot = slot_state
	return best_slot


func _assign_dice_to_slot(dice: Dice, slot_state: Dictionary) -> void:
	if dice == null or slot_state.is_empty():
		return

	_release_dice_from_slot(dice)

	var slot_node := slot_state.get("node") as MeshInstance3D
	if slot_node == null:
		return

	dice.set_meta("ability_slot_gravity_scale", dice.gravity_scale)
	dice.set_meta("ability_slot_lock_rotation", dice.lock_rotation)
	dice.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	dice.freeze = true
	dice.sleeping = true
	dice.gravity_scale = 0.0
	dice.lock_rotation = true
	dice.linear_velocity = Vector3.ZERO
	dice.angular_velocity = Vector3.ZERO
	dice.global_position = _get_slot_target_position(slot_node, dice)

	slot_state["assigned_dice"] = dice
	_dice_to_slot[dice] = slot_state
	_apply_slot_visual(slot_node, true)
	_refresh_all_frame_ready_states()


func _release_dice_from_slot(dice: Dice) -> void:
	if dice == null or not _dice_to_slot.has(dice):
		return
	var slot_state: Dictionary = _dice_to_slot[dice]
	_release_slot(slot_state)
	_refresh_all_frame_ready_states()


func _release_slot(slot_state: Dictionary) -> void:
	if slot_state.is_empty():
		return

	var dice := slot_state.get("assigned_dice") as Dice
	var slot_node := slot_state.get("node") as MeshInstance3D
	if slot_node != null:
		_apply_slot_visual(slot_node, false)

	if dice != null:
		var gravity_scale := 1.0
		if dice.has_meta("ability_slot_gravity_scale"):
			gravity_scale = float(dice.get_meta("ability_slot_gravity_scale"))
		var lock_rotation := false
		if dice.has_meta("ability_slot_lock_rotation"):
			lock_rotation = bool(dice.get_meta("ability_slot_lock_rotation"))
		dice.freeze = false
		dice.gravity_scale = gravity_scale
		dice.lock_rotation = lock_rotation
		_dice_to_slot.erase(dice)

	slot_state["assigned_dice"] = null


func _prune_invalid_assignments() -> void:
	var needs_refresh := false
	for frame_state in _frame_states:
		var slots: Array = frame_state.get("slots", [])
		for slot_state in slots:
			var dice := slot_state.get("assigned_dice") as Dice
			if dice == null or not is_instance_valid(dice):
				if slot_state.get("assigned_dice") != null:
					slot_state["assigned_dice"] = null
					needs_refresh = true
				continue
			if dice.is_dragging():
				_release_slot(slot_state)
				needs_refresh = true
	if needs_refresh:
		_refresh_all_frame_ready_states()


func _track_dice(dice: Dice) -> void:
	if dice == null or _tracked_dice.has(dice):
		return
	_tracked_dice[dice] = true
	if not dice.drag_started.is_connected(_on_dice_drag_started):
		dice.drag_started.connect(_on_dice_drag_started)
	var tree_exit_callable := Callable(self, "_on_dice_tree_exiting").bind(dice)
	_dice_tree_exit_callables[dice] = tree_exit_callable
	if not dice.tree_exiting.is_connected(tree_exit_callable):
		dice.tree_exiting.connect(tree_exit_callable)


func _disconnect_dice_signals(dice: Dice) -> void:
	if dice == null or not is_instance_valid(dice):
		return
	if dice.drag_started.is_connected(_on_dice_drag_started):
		dice.drag_started.disconnect(_on_dice_drag_started)
	if _dice_tree_exit_callables.has(dice):
		var tree_exit_callable: Callable = _dice_tree_exit_callables[dice]
		if dice.tree_exiting.is_connected(tree_exit_callable):
			dice.tree_exiting.disconnect(tree_exit_callable)
		_dice_tree_exit_callables.erase(dice)


func _dice_matches_condition(dice: Dice, condition: AbilityDiceCondition) -> bool:
	if dice == null or condition == null:
		return false

	if condition.scope == AbilityDiceCondition.Scope.MAP:
		return false
	if condition.required_tags.size() > 0:
		return false

	var top_face := dice.get_top_face()
	if top_face == null:
		return false

	if condition.accepted_face_ids.size() > 0 and not condition.accepted_face_ids.has(top_face.text_value):
		return false

	var parsed_value := _parse_top_face_value(top_face.text_value)
	if parsed_value == null:
		return condition.min_value <= 0 and condition.max_value >= 99

	if not condition.matches_value(parsed_value):
		return false

	return true


func _parse_top_face_value(text_value: String) -> Variant:
	var trimmed := text_value.strip_edges()
	if trimmed.is_empty():
		return null
	if not trimmed.is_valid_int():
		return null
	return int(trimmed)


func _get_slot_target_position(slot_node: MeshInstance3D, dice: Dice) -> Vector3:
	var slot_position := slot_node.global_position
	var half_height := 0.1
	if dice != null and dice.definition != null:
		half_height = dice.definition.get_resolved_size().y * dice.extra_size_multiplier.y * 0.5
	return slot_position + Vector3.UP * half_height


func _refresh_all_frame_ready_states() -> void:
	for frame_state in _frame_states:
		_refresh_frame_ready_state(frame_state)


func _refresh_frame_ready_state(frame_state: Dictionary) -> void:
	var slots: Array = frame_state.get("slots", [])
	var is_ready := not slots.is_empty()
	for slot_state in slots:
		if slot_state.get("assigned_dice") == null:
			is_ready = false
			break

	var previous_ready := frame_state.get("is_ready", false)
	frame_state["is_ready"] = is_ready
	var frame := frame_state.get("frame") as MeshInstance3D
	if frame != null:
		frame.set_meta("ability_ready", is_ready)
		_apply_frame_ready_visual(frame, is_ready)

	if previous_ready != is_ready:
		frame_ready_state_changed.emit(frame_state.get("ability") as AbilityDefinition, is_ready)


func _apply_slot_visual(slot_node: MeshInstance3D, is_filled: bool) -> void:
	if slot_node == null:
		return
	var material := _ensure_unique_standard_material(slot_node)
	if material == null:
		return
	material.albedo_color = FILLED_SLOT_COLOR if is_filled else OPEN_SLOT_COLOR


func _apply_frame_ready_visual(frame: MeshInstance3D, is_ready: bool) -> void:
	if frame == null:
		return
	var material := _ensure_unique_standard_material(frame)
	if material == null:
		return
	material.albedo_color = READY_FRAME_COLOR if is_ready else DEFAULT_FRAME_COLOR


func _ensure_unique_standard_material(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	if mesh_instance == null:
		return null

	var current_material := mesh_instance.material_override
	var standard_material := current_material as StandardMaterial3D
	if standard_material == null:
		return null

	if not mesh_instance.has_meta(&"battle_runtime_material_initialized"):
		standard_material = standard_material.duplicate()
		mesh_instance.material_override = standard_material
		mesh_instance.set_meta(&"battle_runtime_material_initialized", true)
	else:
		standard_material = mesh_instance.material_override as StandardMaterial3D
	return standard_material


func _on_dice_drag_started(dice: Dice) -> void:
	_release_dice_from_slot(dice)


func _on_dice_tree_exiting(dice: Dice) -> void:
	_release_dice_from_slot(dice)
	_tracked_dice.erase(dice)
	_dice_tree_exit_callables.erase(dice)
