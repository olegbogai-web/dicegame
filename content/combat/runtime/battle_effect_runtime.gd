extends RefCounted
class_name BattleEffectRuntime

const BattleTurnRuntime = preload("res://content/combat/runtime/battle_turn_runtime.gd")
const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")
const StatusRuntime = preload("res://content/statuses/runtime/status_runtime.gd")


static func activate_current_turn_ability(battle_room, ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	if ability == null or battle_room.current_turn_owner == &"none" or BattleTurnRuntime.is_battle_over(battle_room):
		return {
			"success": false,
			"affected_targets": [],
			"battle_finished": BattleTurnRuntime.is_battle_over(battle_room),
		}
	if not battle_room.can_activate_current_turn_ability(ability):
		_log_debug("ability blocked by cooldown: %s" % String(ability.ability_id))
		return {
			"success": false,
			"affected_targets": [],
			"battle_finished": BattleTurnRuntime.is_battle_over(battle_room),
		}

	var affected_targets: Array[Dictionary] = []
	var applied_any_effect := false
	var consumed_dice: Array[Dice] = []
	for raw_dice in target_descriptor.get("consumed_dice", []):
		if is_instance_valid(raw_dice) and raw_dice is Dice:
			consumed_dice.append(raw_dice as Dice)

	var source_descriptor := _resolve_current_turn_source_descriptor(battle_room)
	StatusRuntime.trigger_event(StatusRuntime.build_event_context(
		StatusRuntime.TRIGGER_ABILITY_BEFORE_RESOLVE,
		{
			"battle_room": battle_room,
			"owner_descriptor": source_descriptor,
			"source_descriptor": source_descriptor,
			"ability": ability,
			"metadata": {
				"target_descriptor": target_descriptor,
			},
		}
	))

	for effect in ability.effects:
		if effect == null:
			continue
		var effect_targets := _resolve_effect_targets(battle_room, target_descriptor)
		for effect_target in effect_targets:
			if _apply_effect_to_target(battle_room, ability, effect, effect_target, consumed_dice, source_descriptor):
				affected_targets.append(effect_target)
				applied_any_effect = true

	StatusRuntime.trigger_event(StatusRuntime.build_event_context(
		StatusRuntime.TRIGGER_ABILITY_AFTER_RESOLVE,
		{
			"battle_room": battle_room,
			"owner_descriptor": source_descriptor,
			"source_descriptor": source_descriptor,
			"ability": ability,
			"metadata": {
				"affected_targets": affected_targets,
				"consumed_dice_count": consumed_dice.size(),
			},
		}
	))

	if applied_any_effect:
		battle_room.register_current_turn_ability_use(ability)
	BattleTurnRuntime.update_battle_result_if_finished(battle_room)
	return {
		"success": applied_any_effect,
		"affected_targets": affected_targets,
		"battle_finished": BattleTurnRuntime.is_battle_over(battle_room),
		"battle_result": battle_room.battle_result,
	}


static func _resolve_effect_targets(battle_room, target_descriptor: Dictionary) -> Array[Dictionary]:
	var target_kind := StringName(target_descriptor.get("kind", &""))
	var resolved_targets: Array[Dictionary] = []
	if target_kind == &"all_monsters":
		for monster_index in battle_room.get_living_monster_indexes():
			resolved_targets.append({
				"kind": &"monster",
				"index": monster_index,
			})
		return resolved_targets
	if target_kind == &"monster":
		var monster_index := int(target_descriptor.get("index", -1))
		if battle_room.can_target_monster(monster_index):
			resolved_targets.append(target_descriptor)
		return resolved_targets
	if target_kind == &"dice" or target_kind == &"dice_group":
		if not _collect_reroll_dice_targets(target_descriptor).is_empty():
			resolved_targets.append(target_descriptor)
		return resolved_targets
	if target_kind == &"player" and battle_room.can_target_player():
		resolved_targets.append(target_descriptor)
	return resolved_targets


static func _apply_effect_to_target(
	battle_room,
	ability: AbilityDefinition,
	effect: AbilityEffectDefinition,
	target_descriptor: Dictionary,
	consumed_dice: Array[Dice],
	source_descriptor: Dictionary
) -> bool:
	var target_kind := StringName(target_descriptor.get("kind", &""))
	var source_container = _resolve_source_status_container(battle_room)
	var target_container = _resolve_target_status_container(battle_room, target_descriptor)
	var resolved_magnitude := StatusRuntime.resolve_ability_effect_magnitude(
		effect,
		consumed_dice,
		source_container,
		target_container
	)
	match effect.effect_type:
		&"damage":
			if target_kind == &"monster":
				var monster_index := int(target_descriptor.get("index", -1))
				if not battle_room.can_target_monster(monster_index):
					return false
				if not battle_room.apply_damage_to_descriptor({"side": &"enemy", "index": monster_index}, resolved_magnitude):
					return false
				StatusRuntime.trigger_event(StatusRuntime.build_event_context(
					StatusRuntime.TRIGGER_DAMAGE_TAKEN,
					{
						"battle_room": battle_room,
						"owner_descriptor": {"side": &"enemy", "index": monster_index},
						"source_descriptor": source_descriptor,
						"target_descriptor": {"side": &"enemy", "index": monster_index},
						"ability": ability,
						"ability_effect": effect,
						"magnitude": resolved_magnitude,
						"metadata": {"origin": &"ability"},
					}
				))
				return true
			if target_kind == &"player":
				if not battle_room.apply_damage_to_descriptor({"side": &"player"}, resolved_magnitude):
					return false
				StatusRuntime.trigger_event(StatusRuntime.build_event_context(
					StatusRuntime.TRIGGER_DAMAGE_TAKEN,
					{
						"battle_room": battle_room,
						"owner_descriptor": {"side": &"player"},
						"source_descriptor": source_descriptor,
						"target_descriptor": {"side": &"player"},
						"ability": ability,
						"ability_effect": effect,
						"magnitude": resolved_magnitude,
						"metadata": {"origin": &"ability"},
					}
				))
				return true
		&"healing":
			if target_kind == &"player":
				if not battle_room.apply_heal_to_descriptor({"side": &"player"}, resolved_magnitude):
					return false
				StatusRuntime.trigger_event(StatusRuntime.build_event_context(
					StatusRuntime.TRIGGER_HEAL_TAKEN,
					{
						"battle_room": battle_room,
						"owner_descriptor": {"side": &"player"},
						"source_descriptor": source_descriptor,
						"target_descriptor": {"side": &"player"},
						"ability": ability,
						"ability_effect": effect,
						"magnitude": resolved_magnitude,
						"metadata": {"origin": &"ability"},
					}
				))
				return true
			if target_kind == &"monster":
				var monster_index := int(target_descriptor.get("index", -1))
				if not battle_room.can_target_monster(monster_index):
					return false
				if not battle_room.apply_heal_to_descriptor({"side": &"enemy", "index": monster_index}, resolved_magnitude):
					return false
				StatusRuntime.trigger_event(StatusRuntime.build_event_context(
					StatusRuntime.TRIGGER_HEAL_TAKEN,
					{
						"battle_room": battle_room,
						"owner_descriptor": {"side": &"enemy", "index": monster_index},
						"source_descriptor": source_descriptor,
						"target_descriptor": {"side": &"enemy", "index": monster_index},
						"ability": ability,
						"ability_effect": effect,
						"magnitude": resolved_magnitude,
						"metadata": {"origin": &"ability"},
					}
				))
				return true
		&"apply_status":
			var status_definition := _resolve_status_definition(effect)
			if status_definition == null:
				_log_debug("apply_status skipped: no status definition for effect=%s" % String(effect.effect_id))
				return false
			var status_stacks := maxi(int(effect.parameters.get("stacks", 1)), 1)
			var status_target := _to_status_descriptor(target_descriptor)
			if status_target.is_empty():
				_log_debug("apply_status skipped: unresolved target descriptor kind=%s" % String(target_kind))
				return false
			_log_debug(
				"apply_status request: ability=%s effect=%s status=%s base_stacks=%d source=%s target=%s" % [
					String(ability.ability_id),
					String(effect.effect_id),
					String(status_definition.status_id),
					status_stacks,
					JSON.stringify(source_descriptor),
					JSON.stringify(status_target),
				]
			)
			return StatusRuntime.apply_status(battle_room, status_target, status_definition, status_stacks, source_descriptor)
		&"reroll_dice":
			if target_kind != &"dice" and target_kind != &"dice_group":
				_log_debug("reroll_dice skipped: target kind is not dice")
				return false
			var reroll_targets := _collect_reroll_dice_targets(target_descriptor)
			if reroll_targets.is_empty():
				_log_debug("reroll_dice skipped: target dice is invalid")
				return false
			var rerolled_count := _reroll_dice_targets(reroll_targets)
			if rerolled_count <= 0:
				_log_debug("reroll_dice skipped: no valid reroll requests")
				return false
			_log_debug(
				"reroll_dice applied: ability=%s effect=%s rerolled=%d" % [
					String(ability.ability_id),
					String(effect.effect_id),
					rerolled_count,
				]
			)
			return rerolled_count > 0
	return false


static func _collect_reroll_dice_targets(target_descriptor: Dictionary) -> Array[Dice]:
	var resolved_targets: Array[Dice] = []
	var seen_instance_ids := {}
	_append_unique_reroll_die(resolved_targets, seen_instance_ids, target_descriptor.get("dice"))
	for raw_dice in target_descriptor.get("dice_list", []):
		_append_unique_reroll_die(resolved_targets, seen_instance_ids, raw_dice)
	return resolved_targets


static func _append_unique_reroll_die(
	resolved_targets: Array[Dice],
	seen_instance_ids: Dictionary,
	candidate
) -> void:
	if not (candidate is Dice):
		return
	var target_dice := candidate as Dice
	if target_dice == null or not is_instance_valid(target_dice):
		return
	var instance_id := target_dice.get_instance_id()
	if seen_instance_ids.has(instance_id):
		return
	seen_instance_ids[instance_id] = true
	resolved_targets.append(target_dice)


static func _reroll_dice_targets(target_dice: Array[Dice]) -> int:
	var requests_by_board: Dictionary = {}
	var reroll_requests_count := 0
	for dice in target_dice:
		if dice == null or not is_instance_valid(dice):
			continue
		var board := dice.get_parent() as BoardController
		if board == null:
			continue
		var reroll_request := _build_reroll_throw_request(board, dice)
		if reroll_request == null:
			continue
		if not requests_by_board.has(board):
			requests_by_board[board] = []
		var board_requests: Array[DiceThrowRequest] = requests_by_board[board]
		board_requests.append(reroll_request)
		requests_by_board[board] = board_requests
		dice.queue_free()
		reroll_requests_count += 1
	for board in requests_by_board.keys():
		var board_requests: Array[DiceThrowRequest] = requests_by_board[board]
		if board_requests.is_empty():
			continue
		board.throw_dice(board_requests)
	return reroll_requests_count


static func _build_reroll_throw_request(board: BoardController, source_dice: Dice) -> DiceThrowRequest:
	if board == null or source_dice == null:
		return null
	var dice_scene: PackedScene = null
	if not source_dice.scene_file_path.is_empty():
		var loaded_scene := load(source_dice.scene_file_path)
		if loaded_scene is PackedScene:
			dice_scene = loaded_scene as PackedScene
	if dice_scene == null:
		dice_scene = board.default_dice_scene
	if dice_scene == null:
		return null
	var metadata := _extract_dice_metadata(source_dice)
	if source_dice.definition != null:
		metadata["definition"] = source_dice.definition
	return DiceThrowRequestScript.create(
		dice_scene,
		Vector3.ZERO,
		maxf(source_dice.mass, 0.001),
		source_dice.extra_size_multiplier,
		metadata
	)


static func _extract_dice_metadata(source_dice: Dice) -> Dictionary:
	var metadata := {}
	if source_dice == null:
		return metadata
	for meta_key in source_dice.get_meta_list():
		var resolved_key := StringName(meta_key)
		metadata[resolved_key] = source_dice.get_meta(resolved_key)
	return metadata


static func _resolve_source_status_container(battle_room):
	if battle_room.current_turn_owner == &"player":
		if not battle_room.can_target_player():
			return null
		return battle_room.get_status_container_for_descriptor({"side": &"player"})
	if battle_room.current_turn_owner == &"monster" and battle_room.can_target_monster(battle_room.current_monster_turn_index):
		return battle_room.get_status_container_for_descriptor({"side": &"enemy", "index": battle_room.current_monster_turn_index})
	return null


static func _resolve_target_status_container(battle_room, target_descriptor: Dictionary):
	var target_kind := StringName(target_descriptor.get("kind", &""))
	if target_kind == &"player":
		if battle_room.player_view == null:
			return null
		return battle_room.get_status_container_for_descriptor({"side": &"player"})
	if target_kind == &"monster":
		var monster_index := int(target_descriptor.get("index", -1))
		if not battle_room.can_target_monster(monster_index):
			return null
		return battle_room.get_status_container_for_descriptor({"side": &"enemy", "index": monster_index})
	return null


static func _resolve_status_definition(effect: AbilityEffectDefinition) -> StatusDefinition:
	if effect == null:
		return null
	if effect.parameters.has("status_definition") and effect.parameters["status_definition"] is StatusDefinition:
		return effect.parameters["status_definition"] as StatusDefinition
	return null


static func _resolve_current_turn_source_descriptor(battle_room) -> Dictionary:
	if battle_room.current_turn_owner == &"player":
		return {"side": &"player"}
	if battle_room.current_turn_owner == &"monster" and battle_room.can_target_monster(battle_room.current_monster_turn_index):
		return {"side": &"enemy", "index": battle_room.current_monster_turn_index}
	return {}


static func _to_status_descriptor(target_descriptor: Dictionary) -> Dictionary:
	var target_kind := StringName(target_descriptor.get("kind", &""))
	if target_kind == &"player":
		return {"side": &"player"}
	if target_kind == &"monster":
		return {
			"side": &"enemy",
			"index": int(target_descriptor.get("index", -1)),
		}
	return {}


static func _log_debug(message: String) -> void:
	if not OS.is_debug_build():
		return
	print("[BattleEffectRuntime] %s" % message)
