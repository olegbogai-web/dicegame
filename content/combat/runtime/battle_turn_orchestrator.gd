extends RefCounted
class_name BattleTurnOrchestrator

const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const MonsterTurnRuntime = preload("res://content/monster_ai/monster_turn_runtime.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const MONSTER_TURN_INACTIVITY_TIMEOUT_SECONDS := 3.0
const MONSTER_TURN_WATCHDOG_POLL_SECONDS := 0.2

var _turn_transition_in_progress := false
var _monster_turn_watchdog_id := 0


func start_current_turn(context: Dictionary) -> void:
	var battle_room_data: BattleRoom = context.get("battle_room_data")
	if battle_room_data == null:
		return
	clear_board_dice(context)
	if battle_room_data.is_battle_over():
		context.get("update_turn_ui", Callable()).call()
		return
	throw_current_turn_dice(context)
	if battle_room_data.is_monster_turn():
		battle_room_data.trigger_turn_start_effects_for_current_owner()
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
	if not requests.is_empty():
		board.throw_dice(requests)
	if battle_room_data.is_player_turn():
		battle_room_data.trigger_turn_start_effects_for_current_owner()


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
	_monster_turn_watchdog_id += 1
	var watchdog_id := _monster_turn_watchdog_id
	var watchdog_state := {
		"last_progress_msec": Time.get_ticks_msec(),
	}
	_start_monster_turn_watchdog(context, watchdog_id, current_monster_index, watchdog_state)
	await MonsterTurnRuntime.run_turn(owner_node, {
		"battle_room": battle_room_data,
		"monster_index": current_monster_index,
		"provide_turn_dice": func() -> Array[Dice]:
			return get_turn_dice(context, &"monster", current_monster_index),
		"are_turn_dice_stopped": func() -> bool:
			return are_current_monster_turn_dice_stopped(context),
		"execute_ability": func(monster_index: int, ability: AbilityDefinition, target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> void:
			watchdog_state["last_progress_msec"] = Time.get_ticks_msec()
			await execute_ability.call(monster_index, ability, target_descriptor, consumed_dice),
	})
	_monster_turn_watchdog_id += 1
	if battle_room_data == null or owner_node == null or not owner_node.is_inside_tree() or not battle_room_data.is_monster_turn() or battle_room_data.is_battle_over():
		return
	advance_to_next_turn(context)


func _start_monster_turn_watchdog(context: Dictionary, watchdog_id: int, monster_index: int, watchdog_state: Dictionary) -> void:
	var owner_node: Node = context.get("owner_node")
	if owner_node == null or not owner_node.is_inside_tree():
		return
	_run_monster_turn_watchdog(context, watchdog_id, monster_index, watchdog_state)


func _run_monster_turn_watchdog(context: Dictionary, watchdog_id: int, monster_index: int, watchdog_state: Dictionary) -> void:
	while watchdog_id == _monster_turn_watchdog_id:
		var owner_node: Node = context.get("owner_node")
		var battle_room_data: BattleRoom = context.get("battle_room_data")
		if owner_node == null or not owner_node.is_inside_tree() or battle_room_data == null:
			return
		if battle_room_data.is_battle_over() or not battle_room_data.is_monster_turn() or battle_room_data.current_monster_turn_index != monster_index:
			return
		var elapsed_seconds := float(Time.get_ticks_msec() - int(watchdog_state.get("last_progress_msec", Time.get_ticks_msec()))) / 1000.0
		if elapsed_seconds >= MONSTER_TURN_INACTIVITY_TIMEOUT_SECONDS:
			print("[Debug][MonsterAI] watchdog forced turn end: timeout=%.1fs monster=%s index=%d" % [
				MONSTER_TURN_INACTIVITY_TIMEOUT_SECONDS,
				String(battle_room_data.monster_views[monster_index].combatant_id) if battle_room_data.can_target_monster(monster_index) else "unknown",
				monster_index,
			])
			_monster_turn_watchdog_id += 1
			advance_to_next_turn(context)
			return
		await owner_node.get_tree().create_timer(MONSTER_TURN_WATCHDOG_POLL_SECONDS).timeout


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
