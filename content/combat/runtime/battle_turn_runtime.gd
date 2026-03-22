extends RefCounted
class_name BattleTurnRuntime


static func start_battle(battle_room) -> Dictionary:
	_reset_battle_progression(battle_room)
	if update_battle_result_if_finished(battle_room):
		return get_current_turn_context(battle_room)
	battle_room.battle_status = &"active"
	battle_room.current_turn_owner = &"player"
	battle_room.current_monster_turn_index = -1
	battle_room.turn_counter = 1
	return get_current_turn_context(battle_room)


static func get_current_turn_context(battle_room) -> Dictionary:
	return {
		"battle_status": battle_room.battle_status,
		"battle_result": battle_room.battle_result,
		"turn_counter": battle_room.turn_counter,
		"owner": battle_room.current_turn_owner,
		"monster_index": battle_room.current_monster_turn_index,
		"dice_count": get_current_turn_dice_count(battle_room),
	}


static func get_current_turn_dice_count(battle_room) -> int:
	if battle_room.current_turn_owner == &"player":
		return battle_room.player_view.dice_count if battle_room.player_view != null else 0
	if battle_room.current_turn_owner == &"monster" and battle_room.can_target_monster(battle_room.current_monster_turn_index):
		return battle_room.monster_views[battle_room.current_monster_turn_index].dice_count
	return 0


static func is_player_turn(battle_room) -> bool:
	return battle_room.battle_status == &"active" and battle_room.current_turn_owner == &"player"


static func is_monster_turn(battle_room) -> bool:
	return battle_room.battle_status == &"active" and battle_room.current_turn_owner == &"monster"


static func is_battle_over(battle_room) -> bool:
	return battle_room.battle_status == &"victory" or battle_room.battle_status == &"defeat"


static func advance_turn(battle_room) -> Dictionary:
	if update_battle_result_if_finished(battle_room):
		return get_current_turn_context(battle_room)
	if battle_room.battle_status != &"active":
		return get_current_turn_context(battle_room)

	if battle_room.current_turn_owner == &"player":
		var monster_order = battle_room.get_monster_turn_order()
		if monster_order.is_empty():
			update_battle_result_if_finished(battle_room)
			return get_current_turn_context(battle_room)
		battle_room.current_turn_owner = &"monster"
		battle_room.current_monster_turn_index = monster_order[0]
		return get_current_turn_context(battle_room)

	if battle_room.current_turn_owner == &"monster":
		var current_order = battle_room.get_monster_turn_order()
		var next_order_position = current_order.find(battle_room.current_monster_turn_index) + 1
		if next_order_position > 0 and next_order_position < current_order.size():
			battle_room.current_monster_turn_index = current_order[next_order_position]
			return get_current_turn_context(battle_room)
		battle_room.current_turn_owner = &"player"
		battle_room.current_monster_turn_index = -1
		battle_room.turn_counter += 1
		return get_current_turn_context(battle_room)

	return start_battle(battle_room)


static func update_battle_result_if_finished(battle_room) -> bool:
	if battle_room.player_view == null or not battle_room.player_view.is_alive():
		battle_room.battle_status = &"defeat"
		battle_room.battle_result = &"player_dead"
		battle_room.current_turn_owner = &"none"
		battle_room.current_monster_turn_index = -1
		return true
	if battle_room.get_living_monster_indexes().is_empty():
		battle_room.battle_status = &"victory"
		battle_room.battle_result = &"monsters_defeated"
		battle_room.current_turn_owner = &"none"
		battle_room.current_monster_turn_index = -1
		return true
	return false


static func reset_battle_progression(battle_room) -> void:
	_reset_battle_progression(battle_room)


static func _reset_battle_progression(battle_room) -> void:
	battle_room.battle_status = &"not_started"
	battle_room.battle_result = &"none"
	battle_room.current_turn_owner = &"none"
	battle_room.current_monster_turn_index = -1
	battle_room.turn_counter = 0
