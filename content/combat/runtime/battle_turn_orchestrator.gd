extends RefCounted
class_name BattleTurnOrchestrator

const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const MonsterTurnRuntime = preload("res://content/monster_ai/monster_turn_runtime.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")


func _start_current_turn(owner: Node) -> void:
	if owner.battle_room_data == null:
		return
	_clear_board_dice(owner)
	if owner.battle_room_data.is_battle_over():
		owner._handle_post_battle_reward_dice()
		owner._update_turn_ui()
		return
	_throw_current_turn_dice(owner)
	owner._update_turn_ui()
	if owner.battle_room_data.is_monster_turn():
		_run_current_monster_turn(owner)


func _throw_current_turn_dice(owner: Node) -> void:
	if owner._board == null or owner.battle_room_data == null:
		return
	var requests: Array[DiceThrowRequest] = []
	if owner.battle_room_data.is_player_turn() and owner.battle_room_data.player_instance != null:
		for dice_definition in owner.battle_room_data.player_instance.dice_loadout:
			if dice_definition == null:
				continue
			requests.append(_build_dice_throw_request(owner, dice_definition, {"owner": &"player"}))
	elif owner.battle_room_data.is_monster_turn() and owner.battle_room_data.can_target_monster(owner.battle_room_data.current_monster_turn_index):
		var monster_view = owner.battle_room_data.monster_views[owner.battle_room_data.current_monster_turn_index]
		for _index in range(monster_view.dice_count):
			requests.append(_build_dice_throw_request(owner, null, {
				"owner": &"monster",
				"monster_index": owner.battle_room_data.current_monster_turn_index,
			}))
	if not requests.is_empty():
		owner._board.throw_dice(requests)


func _build_dice_throw_request(_owner: Node, dice_definition: DiceDefinition, metadata: Dictionary) -> DiceThrowRequest:
	var request := DiceThrowRequestScript.create(BASE_DICE_SCENE, Vector3.ZERO, 1.0, Vector3.ONE, metadata)
	if dice_definition != null:
		request.metadata["definition"] = dice_definition
	return request


func _clear_board_dice(owner: Node) -> void:
	for dice in owner._get_board_dice():
		if not is_instance_valid(dice):
			continue
		if dice.get_parent() != null:
			dice.get_parent().remove_child(dice)
		dice.queue_free()


func _get_turn_dice(owner: Node, owner_key: StringName, monster_index: int = -1) -> Array[Dice]:
	var owned_dice: Array[Dice] = []
	for dice in owner._get_board_dice():
		if StringName(dice.get_meta(&"owner", &"")) != owner_key:
			continue
		if owner_key == &"monster" and int(dice.get_meta(&"monster_index", -1)) != monster_index:
			continue
		owned_dice.append(dice)
	return owned_dice


func _are_current_monster_turn_dice_stopped(owner: Node) -> bool:
	if owner.battle_room_data == null or not owner.battle_room_data.is_monster_turn():
		return true
	var monster_dice := _get_turn_dice(owner, &"monster", owner.battle_room_data.current_monster_turn_index)
	if monster_dice.is_empty():
		return true
	for dice in monster_dice:
		if not BattleAbilityRuntime.is_die_fully_stopped(dice):
			return false
	return true


func _advance_to_next_turn(owner: Node) -> void:
	if owner.battle_room_data == null or owner._turn_transition_in_progress:
		return
	owner._turn_transition_in_progress = true
	owner.battle_room_data.advance_turn()
	_start_current_turn(owner)
	owner._turn_transition_in_progress = false


func _run_current_monster_turn(owner: Node) -> void:
	if owner.battle_room_data == null or not owner.battle_room_data.is_monster_turn() or owner.battle_room_data.is_battle_over():
		return
	var current_monster_index = owner.battle_room_data.current_monster_turn_index
	await MonsterTurnRuntime.run_turn(owner, {
		"battle_room": owner.battle_room_data,
		"monster_index": current_monster_index,
		"provide_turn_dice": func() -> Array[Dice]:
			return _get_turn_dice(owner, &"monster", current_monster_index),
		"are_turn_dice_stopped": func() -> bool:
			return _are_current_monster_turn_dice_stopped(owner),
		"execute_ability": func(monster_index: int, ability: AbilityDefinition, target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> void:
			await owner._execute_monster_ability(monster_index, ability, target_descriptor, consumed_dice),
	})
	if owner.battle_room_data == null or not owner.is_inside_tree() or not owner.battle_room_data.is_monster_turn() or owner.battle_room_data.is_battle_over():
		return
	_advance_to_next_turn(owner)


func _on_end_turn_button_pressed(owner: Node) -> void:
	if owner.battle_room_data == null or not owner.battle_room_data.is_player_turn() or owner.battle_room_data.is_battle_over():
		return
	owner._cancel_selected_ability()
	_advance_to_next_turn(owner)
