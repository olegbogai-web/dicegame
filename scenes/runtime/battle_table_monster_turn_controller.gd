extends RefCounted
class_name BattleTableMonsterTurnController

const MonsterAiDecisionServiceScript = preload("res://content/monsters/ai/runtime/monster_ai_decision_service.gd")

var _host: Node
var _get_battle_room: Callable
var _get_board_dice: Callable
var _get_monster_frame_state: Callable
var _activation_controller: BattleTableAbilityActivationController
var _refresh_scene_state: Callable
var _advance_turn: Callable
var _is_activation_locked: Callable
var _decision_service := MonsterAiDecisionServiceScript.new()


func configure(
	host: Node,
	get_battle_room: Callable,
	get_board_dice: Callable,
	get_monster_frame_state: Callable,
	activation_controller: BattleTableAbilityActivationController,
	refresh_scene_state: Callable,
	advance_turn: Callable,
	is_activation_locked: Callable
) -> void:
	_host = host
	_get_battle_room = get_battle_room
	_get_board_dice = get_board_dice
	_get_monster_frame_state = get_monster_frame_state
	_activation_controller = activation_controller
	_refresh_scene_state = refresh_scene_state
	_advance_turn = advance_turn
	_is_activation_locked = is_activation_locked


func process_current_turn() -> void:
	var battle_room := _get_battle_room.call() as BattleRoom
	if battle_room == null or not battle_room.is_monster_turn() or battle_room.is_battle_over():
		return

	while _should_continue_turn(battle_room):
		var monster_index := battle_room.current_monster_turn_index
		await _wait_for_monster_dice_to_stop(monster_index)
		if not _should_continue_turn(battle_room):
			return

		var board_dice: Array[Dice] = _get_board_dice.call()
		var monster_definition := battle_room.get_monster_definition(monster_index)
		var monster_dice := _decision_service.collect_monster_dice(board_dice, monster_index)
		var decision := _decision_service.decide_next_action(
			battle_room,
			monster_definition,
			monster_index,
			monster_dice
		)

		if StringName(decision.get("kind", &"")) == &"use_ability":
			await _execute_ability_decision(battle_room, monster_index, decision)
			battle_room = _get_battle_room.call() as BattleRoom
			continue

		_advance_turn.call()
		return


func _execute_ability_decision(battle_room: BattleRoom, monster_index: int, decision: Dictionary) -> void:
	var ability := decision.get("ability") as AbilityDefinition
	var frame_state := _get_monster_frame_state.call(monster_index, ability) as Dictionary
	if frame_state.is_empty():
		_advance_turn.call()
		return

	var consumed_dice: Array[Dice] = []
	for dice in decision.get("consumed_dice", []):
		if dice is Dice:
			consumed_dice.append(dice)
	await _activation_controller.activate_monster_ability(
		battle_room,
		frame_state,
		consumed_dice,
		decision.get("target_descriptor", {})
	)
	_refresh_scene_state.call()


func _wait_for_monster_dice_to_stop(monster_index: int) -> void:
	while true:
		var battle_room := _get_battle_room.call() as BattleRoom
		if battle_room == null or not battle_room.is_monster_turn() or battle_room.is_battle_over():
			return
		if _is_activation_locked.is_valid() and bool(_is_activation_locked.call()):
			await _host.get_tree().process_frame
			continue
		var board_dice: Array[Dice] = _get_board_dice.call()
		if not _decision_service.has_moving_dice(board_dice, monster_index):
			return
		await _host.get_tree().process_frame


func _should_continue_turn(battle_room: BattleRoom) -> bool:
	return battle_room != null and battle_room.is_monster_turn() and not battle_room.is_battle_over()
