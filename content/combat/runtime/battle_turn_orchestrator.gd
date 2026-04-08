extends RefCounted
class_name BattleTurnOrchestrator

const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const MonsterTurnRuntime = preload("res://content/monster_ai/monster_turn_runtime.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const TURN_TRANSFER_DELAY_SEC := 0.3
const VISUAL_SYNC_TIMEOUT_SEC := 2.0
const GOLDEN_DICE_NAME := &"golden"
const GOLDEN_DICE_COINS_ON_THROW := 1

var _turn_transition_in_progress := false
var _dice_selection_rng := RandomNumberGenerator.new()


func _init() -> void:
	_dice_selection_rng.randomize()


func start_current_turn(context: Dictionary) -> void:
	var battle_room_data: BattleRoom = context.get("battle_room_data")
	if battle_room_data == null:
		return
	clear_board_dice(context)
	if battle_room_data.is_battle_over():
		context.get("update_turn_ui", Callable()).call()
		return
	battle_room_data.process_turn_start_if_pending()
	if battle_room_data.is_battle_over():
		context.get("update_turn_ui", Callable()).call()
		return
	throw_current_turn_dice(context)
	context.get("update_turn_ui", Callable()).call()
	if battle_room_data.is_monster_turn():
		run_current_monster_turn(context)


func throw_current_turn_dice(context: Dictionary) -> void:
	var board: BoardController = context.get("board")
	var battle_room_data: BattleRoom = context.get("battle_room_data")
	if board == null or battle_room_data == null:
		return
	var requests: Array[DiceThrowRequest] = []
	if battle_room_data.is_player_turn() and battle_room_data.player_instance != null:
		for dice_definition in battle_room_data.player_instance.dice_loadout:
			if dice_definition == null:
				continue
			if dice_definition.scope != DiceDefinition.Scope.COMBAT:
				continue
			requests.append(build_dice_throw_request(dice_definition, {"owner": &"player"}))
	elif battle_room_data.is_monster_turn() and battle_room_data.can_target_monster(battle_room_data.current_monster_turn_index):
		var monster_view = battle_room_data.monster_views[battle_room_data.current_monster_turn_index]
		if monster_view.dice_loadout.is_empty():
			for _index in range(monster_view.dice_count):
				requests.append(build_dice_throw_request(null, {
					"owner": &"monster",
					"monster_index": battle_room_data.current_monster_turn_index,
				}))
		else:
			for dice_definition in monster_view.dice_loadout:
				if dice_definition == null:
					continue
				requests.append(build_dice_throw_request(dice_definition, {
					"owner": &"monster",
					"monster_index": battle_room_data.current_monster_turn_index,
				}))
	_apply_turn_start_dice_penalty(battle_room_data, requests)
	_apply_player_throw_coin_bonus(battle_room_data, requests)
	if not requests.is_empty():
		board.throw_dice(requests)


func build_dice_throw_request(dice_definition: DiceDefinition, metadata: Dictionary) -> DiceThrowRequest:
	var request := DiceThrowRequestScript.create(BASE_DICE_SCENE, Vector3.ZERO, 1.0, Vector3.ONE, metadata)
	if dice_definition != null:
		request.metadata["definition"] = dice_definition
	return request


func clear_board_dice(context: Dictionary) -> void:
	for dice in _get_board_dice(context.get("board")):
		if not is_instance_valid(dice):
			continue
		if dice.get_parent() != null:
			dice.get_parent().remove_child(dice)
		dice.queue_free()


func get_turn_dice(context: Dictionary, owner_key: StringName, monster_index: int = -1) -> Array[Dice]:
	var owned_dice: Array[Dice] = []
	for dice in _get_board_dice(context.get("board")):
		if StringName(dice.get_meta(&"owner", &"")) != owner_key:
			continue
		if owner_key == &"monster" and int(dice.get_meta(&"monster_index", -1)) != monster_index:
			continue
		owned_dice.append(dice)
	return owned_dice


func are_current_monster_turn_dice_stopped(context: Dictionary) -> bool:
	var battle_room_data: BattleRoom = context.get("battle_room_data")
	if battle_room_data == null or not battle_room_data.is_monster_turn():
		return true
	var monster_dice := get_turn_dice(context, &"monster", battle_room_data.current_monster_turn_index)
	if monster_dice.is_empty():
		return true
	for dice in monster_dice:
		if not BattleAbilityRuntime.is_die_fully_stopped(dice):
			return false
	return true


func advance_to_next_turn(context: Dictionary) -> void:
	var battle_room_data: BattleRoom = context.get("battle_room_data")
	if battle_room_data == null or _turn_transition_in_progress:
		return
	_turn_transition_in_progress = true
	battle_room_data.advance_turn()
	start_current_turn(context)
	_turn_transition_in_progress = false


func run_current_monster_turn(context: Dictionary) -> void:
	var battle_room_data: BattleRoom = context.get("battle_room_data")
	var owner_node: Node = context.get("owner_node")
	if battle_room_data == null or not battle_room_data.is_monster_turn() or battle_room_data.is_battle_over():
		return
	var execute_ability: Callable = context.get("execute_monster_ability", Callable())
	var current_monster_index = battle_room_data.current_monster_turn_index
	await MonsterTurnRuntime.run_turn(owner_node, {
		"battle_room": battle_room_data,
		"monster_index": current_monster_index,
		"post_ability_delay_sec": 0.5,
		"provide_turn_dice": func() -> Array[Dice]:
			return get_turn_dice(context, &"monster", current_monster_index),
		"are_turn_dice_stopped": func() -> bool:
			return are_current_monster_turn_dice_stopped(context),
		"execute_ability": func(monster_index: int, ability: AbilityDefinition, target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> void:
			await execute_ability.call(monster_index, ability, target_descriptor, consumed_dice),
	})
	if battle_room_data == null or owner_node == null or not owner_node.is_inside_tree() or not battle_room_data.is_monster_turn() or battle_room_data.is_battle_over():
		return
	await _wait_until_monster_visuals_complete(context)
	await _wait_delay(owner_node, TURN_TRANSFER_DELAY_SEC)
	advance_to_next_turn(context)


func on_end_turn_button_pressed(context: Dictionary) -> void:
	var battle_room_data: BattleRoom = context.get("battle_room_data")
	if battle_room_data == null or not battle_room_data.is_player_turn() or battle_room_data.is_battle_over():
		return
	context.get("cancel_selected_ability", Callable()).call()
	advance_to_next_turn(context)


func is_turn_transition_in_progress() -> bool:
	return _turn_transition_in_progress


func _get_board_dice(board: BoardController) -> Array[Dice]:
	var dice_list: Array[Dice] = []
	if board == null:
		return dice_list
	for child in board.get_children():
		if child is Dice and is_instance_valid(child):
			dice_list.append(child as Dice)
	return dice_list


func _wait_until_monster_visuals_complete(context: Dictionary) -> void:
	var owner_node: Node = context.get("owner_node")
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
		return
	var are_visuals_busy: Callable = context.get("are_monster_visuals_busy", Callable())
	if not are_visuals_busy.is_valid():
		return
	var wait_started_at_msec := Time.get_ticks_msec()
	while owner_node != null and is_instance_valid(owner_node) and owner_node.is_inside_tree() and are_visuals_busy.call():
		var elapsed_sec := float(Time.get_ticks_msec() - wait_started_at_msec) / 1000.0
		if elapsed_sec >= VISUAL_SYNC_TIMEOUT_SEC:
			break
		await owner_node.get_tree().physics_frame


func _wait_delay(owner_node: Node, seconds: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
		return
	if seconds <= 0.0:
		return
	await owner_node.get_tree().create_timer(seconds).timeout


func _apply_player_throw_coin_bonus(battle_room_data: BattleRoom, requests: Array[DiceThrowRequest]) -> void:
	if battle_room_data == null or requests.is_empty() or not battle_room_data.is_player_turn():
		return
	var player := battle_room_data.player_instance
	if player == null:
		return
	var bonus_coins := 0
	for request in requests:
		if request == null:
			continue
		var dice_definition := request.metadata.get("definition") as DiceDefinition
		if dice_definition == null:
			continue
		if StringName(dice_definition.dice_name) == GOLDEN_DICE_NAME:
			bonus_coins += GOLDEN_DICE_COINS_ON_THROW
	if bonus_coins > 0:
		player.add_coins(bonus_coins)


func _apply_turn_start_dice_penalty(battle_room_data: BattleRoom, requests: Array[DiceThrowRequest]) -> void:
	if battle_room_data == null or requests.is_empty():
		return
	var owner_descriptor := {}
	if battle_room_data.is_player_turn():
		owner_descriptor = {"side": &"player"}
	elif battle_room_data.is_monster_turn():
		owner_descriptor = {
			"side": &"enemy",
			"index": battle_room_data.current_monster_turn_index,
		}
	if owner_descriptor.is_empty():
		return
	var penalty := battle_room_data.consume_turn_start_dice_penalty(owner_descriptor)
	if penalty <= 0:
		return
	var available_count := requests.size()
	var resolved_penalty := mini(maxi(penalty, 0), available_count)
	if resolved_penalty <= 0:
		return
	var removable_indexes: Array[int] = []
	for index in available_count:
		removable_indexes.append(index)
	for _step in resolved_penalty:
		if removable_indexes.is_empty():
			break
		var random_slot := _dice_selection_rng.randi_range(0, removable_indexes.size() - 1)
		var remove_index := removable_indexes[random_slot]
		removable_indexes.remove_at(random_slot)
		requests.remove_at(remove_index)
		for item_index in removable_indexes.size():
			if removable_indexes[item_index] > remove_index:
				removable_indexes[item_index] -= 1
	_log_debug(
		"Применен штраф на кубы в начале хода: owner=%s penalty=%d removed=%d remaining=%d." % [
			_format_turn_owner(owner_descriptor),
			penalty,
			resolved_penalty,
			requests.size(),
		]
	)


func _log_debug(message: String) -> void:
	if not OS.is_debug_build():
		return
	print("[BattleTurnOrchestrator] %s" % message)


func _format_turn_owner(descriptor: Dictionary) -> String:
	var side := StringName(descriptor.get("side", &""))
	if side == &"player":
		return "игрок"
	if side == &"enemy":
		return "монстр #%d" % (int(descriptor.get("index", -1)) + 1)
	return "неизвестно"
