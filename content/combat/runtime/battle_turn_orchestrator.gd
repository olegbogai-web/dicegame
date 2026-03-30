extends RefCounted
class_name BattleTurnOrchestrator

const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const MonsterTurnRuntime = preload("res://content/monster_ai/monster_turn_runtime.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")

var _turn_transition_in_progress := false


func is_turn_transition_in_progress() -> bool:
	return _turn_transition_in_progress


func start_current_turn(ctx: Dictionary) -> void:
	var battle_room: BattleRoom = ctx.get("battle_room") as BattleRoom
	if battle_room == null:
		return
	clear_board_dice(ctx)
	if battle_room.is_battle_over():
		var on_battle_over := ctx.get("on_battle_over") as Callable
		if on_battle_over.is_valid():
			on_battle_over.call()
		return
	throw_current_turn_dice(ctx)
	var update_turn_ui := ctx.get("update_turn_ui") as Callable
	if update_turn_ui.is_valid():
		update_turn_ui.call()
	if battle_room.is_monster_turn():
		run_current_monster_turn(ctx)


func throw_current_turn_dice(ctx: Dictionary) -> void:
	var board := ctx.get("board") as Node
	var battle_room: BattleRoom = ctx.get("battle_room") as BattleRoom
	if board == null or battle_room == null:
		return
	var requests: Array[DiceThrowRequest] = []
	if battle_room.is_player_turn() and battle_room.player_instance != null:
		for dice_definition in battle_room.player_instance.dice_loadout:
			if dice_definition == null:
				continue
			requests.append(build_dice_throw_request(dice_definition, {"owner": &"player"}))
	elif battle_room.is_monster_turn() and battle_room.can_target_monster(battle_room.current_monster_turn_index):
		var monster_view := battle_room.monster_views[battle_room.current_monster_turn_index]
		for _index in range(monster_view.dice_count):
			requests.append(build_dice_throw_request(null, {
				"owner": &"monster",
				"monster_index": battle_room.current_monster_turn_index,
			}))
	if not requests.is_empty() and board.has_method("throw_dice"):
		board.throw_dice(requests)


func build_dice_throw_request(dice_definition: DiceDefinition, metadata: Dictionary) -> DiceThrowRequest:
	var request := DiceThrowRequestScript.create(BASE_DICE_SCENE, Vector3.ZERO, 1.0, Vector3.ONE, metadata)
	if dice_definition != null:
		request.metadata["definition"] = dice_definition
	return request


func clear_board_dice(ctx: Dictionary) -> void:
	for dice in _get_board_dice(ctx):
		if not is_instance_valid(dice):
			continue
		if dice.get_parent() != null:
			dice.get_parent().remove_child(dice)
		dice.queue_free()


func get_turn_dice(ctx: Dictionary, owner_key: StringName, monster_index: int = -1) -> Array[Dice]:
	var owned_dice: Array[Dice] = []
	for dice in _get_board_dice(ctx):
		if StringName(dice.get_meta(&"owner", &"")) != owner_key:
			continue
		if owner_key == &"monster" and int(dice.get_meta(&"monster_index", -1)) != monster_index:
			continue
		owned_dice.append(dice)
	return owned_dice


func are_current_monster_turn_dice_stopped(ctx: Dictionary) -> bool:
	var battle_room: BattleRoom = ctx.get("battle_room") as BattleRoom
	if battle_room == null or not battle_room.is_monster_turn():
		return true
	var monster_dice := get_turn_dice(ctx, &"monster", battle_room.current_monster_turn_index)
	if monster_dice.is_empty():
		return true
	for dice in monster_dice:
		if not BattleAbilityRuntime.is_die_fully_stopped(dice):
			return false
	return true


func advance_to_next_turn(ctx: Dictionary) -> void:
	var battle_room: BattleRoom = ctx.get("battle_room") as BattleRoom
	if battle_room == null or _turn_transition_in_progress:
		return
	_turn_transition_in_progress = true
	battle_room.advance_turn()
	start_current_turn(ctx)
	_turn_transition_in_progress = false


func run_current_monster_turn(ctx: Dictionary) -> void:
	var battle_room: BattleRoom = ctx.get("battle_room") as BattleRoom
	if battle_room == null or not battle_room.is_monster_turn() or battle_room.is_battle_over():
		return
	var current_monster_index := battle_room.current_monster_turn_index
	var execute_monster_ability := ctx.get("execute_monster_ability") as Callable
	await MonsterTurnRuntime.run_turn(ctx.get("host"), {
		"battle_room": battle_room,
		"monster_index": current_monster_index,
		"provide_turn_dice": func() -> Array[Dice]:
			return get_turn_dice(ctx, &"monster", current_monster_index),
		"are_turn_dice_stopped": func() -> bool:
			return are_current_monster_turn_dice_stopped(ctx),
		"execute_ability": func(monster_index: int, ability: AbilityDefinition, target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> void:
			if execute_monster_ability.is_valid():
				await execute_monster_ability.call(monster_index, ability, target_descriptor, consumed_dice),
	})
	if battle_room == null or not (ctx.get("host") as Node).is_inside_tree() or not battle_room.is_monster_turn() or battle_room.is_battle_over():
		return
	advance_to_next_turn(ctx)


func on_end_turn_button_pressed(ctx: Dictionary) -> void:
	var battle_room: BattleRoom = ctx.get("battle_room") as BattleRoom
	if battle_room == null or not battle_room.is_player_turn() or battle_room.is_battle_over():
		return
	var cancel_selected_ability := ctx.get("cancel_selected_ability") as Callable
	if cancel_selected_ability.is_valid():
		cancel_selected_ability.call()
	advance_to_next_turn(ctx)


func _get_board_dice(ctx: Dictionary) -> Array[Dice]:
	var provide_board_dice := ctx.get("provide_board_dice") as Callable
	if provide_board_dice.is_valid():
		return provide_board_dice.call()
	return []
