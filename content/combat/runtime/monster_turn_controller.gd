extends RefCounted
class_name MonsterTurnController

const BattleDiceRules = preload("res://content/combat/runtime/battle_dice_rules.gd")
const BattleAbilityPresentation = preload("res://content/combat/runtime/battle_ability_presentation.gd")
const MonsterAIRegistry = preload("res://content/monster_ai/monster_ai_registry.gd")
const Dice = preload("res://content/dice/dice.gd")

var _battle_table: Node


func _init(battle_table: Node) -> void:
	_battle_table = battle_table


func process_current_turn() -> void:
	if _battle_table == null or not _battle_table.has_method("get_battle_room_data"):
		return
	var battle_room: BattleRoom = _battle_table.get_battle_room_data()
	if battle_room == null or not battle_room.is_monster_turn() or battle_room.is_battle_over():
		return

	var monster_index := battle_room.current_monster_turn_index
	var monster_dice := _get_monster_dice(monster_index)
	while not BattleDiceRules.are_all_dice_stopped(monster_dice):
		await _battle_table.get_tree().process_frame
		if not _can_continue_turn(monster_index):
			return
		monster_dice = _get_monster_dice(monster_index)

	while _can_continue_turn(monster_index):
		monster_dice = BattleDiceRules.get_available_dice(_get_monster_dice(monster_index), true)
		if monster_dice.is_empty():
			_end_turn(&"no_dice_left")
			return

		var monster_abilities := battle_room.get_monster_abilities_for(monster_index)
		if not BattleDiceRules.monster_has_usable_ability(monster_abilities, monster_dice):
			_end_turn(&"no_usable_abilities")
			return

		var ai_profile := MonsterAIRegistry.resolve_profile(battle_room.get_monster_ai_profile_id(monster_index))
		var action := ai_profile.decide_next_action(battle_room, monster_index, monster_dice)
		var action_kind := StringName(action.get("kind", &"end_turn"))
		if action_kind != &"use_ability":
			_end_turn(StringName(action.get("reason", &"ai_end_turn_signal")))
			return

		await _use_ability(monster_index, action)
		if battle_room.is_battle_over():
			return


func _use_ability(monster_index: int, action: Dictionary) -> void:
	var battle_room: BattleRoom = _battle_table.get_battle_room_data()
	var ability := action.get("ability") as AbilityDefinition
	if ability == null:
		_end_turn(&"missing_ability")
		return

	var frame_state := _battle_table.get_monster_ability_frame_state(monster_index, ability)
	if frame_state.is_empty():
		_end_turn(&"missing_ability_frame")
		return

	var frame := frame_state.get("frame") as MeshInstance3D
	var base_origin: Vector3 = frame_state.get("base_origin", frame.transform.origin)
	var target_descriptor := action.get("target", {"kind": &"player"})
	var dice_assignments: Array[Dictionary] = action.get("dice_assignments", [])
	var dice_places := _battle_table.get_dice_place_nodes_for_frame(frame)
	var move_assignments := BattleAbilityPresentation.build_slot_move_assignments(
		dice_assignments,
		dice_places,
		Callable(_battle_table, "get_slot_target_position")
	)
	await BattleAbilityPresentation.move_dice_to_slots(_battle_table, move_assignments)

	var consumed_dice: Array[Dice] = []
	for assignment in dice_assignments:
		var assigned_dice := assignment.get("dice") as Dice
		if assigned_dice != null:
			consumed_dice.append(assigned_dice)

	_battle_table.set_activation_in_progress(true)
	var target_origin := _battle_table.resolve_activation_target_origin(target_descriptor, base_origin)
	await BattleAbilityPresentation.play_ability_use(
		_battle_table,
		frame,
		base_origin,
		consumed_dice,
		target_origin,
		func() -> void:
			battle_room.activate_monster_ability(monster_index, ability, target_descriptor),
		_battle_table.get_activation_animation_duration(),
		_battle_table.get_selected_frame_lift_y()
	)
	_battle_table.set_activation_in_progress(false)
	_battle_table.refresh_battle_view()


func _get_monster_dice(monster_index: int) -> Array[Dice]:
	return BattleDiceRules.get_dice_for_owner(_battle_table.get_board_controller(), &"monster", monster_index)


func _can_continue_turn(monster_index: int) -> bool:
	var battle_room: BattleRoom = _battle_table.get_battle_room_data()
	return _battle_table != null \
		and _battle_table.is_inside_tree() \
		and battle_room != null \
		and battle_room.is_monster_turn() \
		and not battle_room.is_battle_over() \
		and battle_room.current_monster_turn_index == monster_index


func _end_turn(reason: StringName) -> void:
	if _battle_table != null and _battle_table.has_method("advance_to_next_turn"):
		_battle_table.advance_to_next_turn(reason)
