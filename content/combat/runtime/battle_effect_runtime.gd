extends RefCounted
class_name BattleEffectRuntime

const BattleTurnRuntime = preload("res://content/combat/runtime/battle_turn_runtime.gd")
const Dice = preload("res://content/dice/dice.gd")
const StatusRuntime = preload("res://content/statuses/runtime/status_runtime.gd")

const KAMIKAZE_DICE_NAME := &"kamikaze"


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
		if not _passes_effect_chance(effect):
			_log_debug(
				"effect skipped by chance: ability=%s effect=%s chance=%.3f" % [
					String(ability.ability_id),
					String(effect.effect_id),
					clampf(float(effect.chance), 0.0, 1.0),
				]
			)
			continue
		var effect_targets := _resolve_effect_targets(battle_room, target_descriptor)
		for effect_target in effect_targets:
			if _apply_effect_to_target(battle_room, ability, effect, effect_target, consumed_dice, source_descriptor):
				affected_targets.append(effect_target)
				applied_any_effect = true

	if _has_consumed_dice_with_name(consumed_dice, KAMIKAZE_DICE_NAME):
		if _reroll_remaining_player_dice(target_descriptor, consumed_dice):
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
	if target_kind == &"dice":
		var target_dice = target_descriptor.get("dice") as Dice
		if target_dice != null and is_instance_valid(target_dice):
			resolved_targets.append(target_descriptor)
		return resolved_targets
	if target_kind == &"global":
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
			var status_target := _resolve_apply_status_target_descriptor(effect, target_descriptor, source_descriptor)
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
		&"heal_if_target_dead":
			if target_kind != &"monster":
				_log_debug("heal_if_target_dead skipped: unsupported target_kind=%s" % String(target_kind))
				return false
			var dead_monster_index := int(target_descriptor.get("index", -1))
			if dead_monster_index < 0 or dead_monster_index >= battle_room.monster_views.size():
				_log_debug("heal_if_target_dead skipped: invalid monster index=%d" % dead_monster_index)
				return false
			var dead_monster_view := battle_room.monster_views[dead_monster_index]
			if dead_monster_view == null or dead_monster_view.is_alive():
				_log_debug(
					"heal_if_target_dead skipped: monster still alive ability=%s effect=%s target_index=%d" % [
						String(ability.ability_id),
						String(effect.effect_id),
						dead_monster_index,
					]
				)
				return false
			var heal_target_side := StringName(effect.parameters.get("heal_target_side", &"player"))
			var heal_target_descriptor := {"side": heal_target_side}
			if heal_target_side == &"enemy":
				heal_target_descriptor = {
					"side": &"enemy",
					"index": int(effect.parameters.get("heal_target_index", dead_monster_index)),
				}
			if not battle_room.apply_heal_to_descriptor(heal_target_descriptor, resolved_magnitude):
				_log_debug(
					"heal_if_target_dead skipped: heal application failed ability=%s effect=%s heal_target=%s magnitude=%d" % [
						String(ability.ability_id),
						String(effect.effect_id),
						JSON.stringify(heal_target_descriptor),
						resolved_magnitude,
					]
				)
				return false
			_log_debug(
				"heal_if_target_dead applied: ability=%s effect=%s dead_target_index=%d heal_target=%s magnitude=%d" % [
					String(ability.ability_id),
					String(effect.effect_id),
					dead_monster_index,
					JSON.stringify(heal_target_descriptor),
					resolved_magnitude,
				]
			)
			return true
		&"reroll_dice":
			var dice_to_reroll := _resolve_reroll_dice_targets(effect, target_descriptor, consumed_dice)
			if dice_to_reroll.is_empty():
				_log_debug("reroll_dice skipped: no valid target dice")
				return false
			var rerolled_dice := Dice.reroll_group_with_board_throw(dice_to_reroll)
			var is_successful := not rerolled_dice.is_empty()
			if is_successful:
				_log_debug(
					"reroll_dice applied: ability=%s effect=%s source_count=%d rerolled_count=%d" % [
						String(ability.ability_id),
						String(effect.effect_id),
						dice_to_reroll.size(),
						rerolled_dice.size(),
					]
				)
			else:
				_log_debug("reroll_dice skipped: board reroll produced no dice")
			return is_successful
		&"reroll_random_player_die":
			var random_reroll_target := _pick_random_reroll_candidate(target_descriptor, consumed_dice)
			if random_reroll_target == null:
				_log_debug("reroll_random_player_die skipped: no valid random target")
				return false
			var rerolled_random := Dice.throw_copies_group_with_board_throw([random_reroll_target])
			var reroll_success := not rerolled_random.is_empty()
			if reroll_success:
				_log_debug(
					"reroll_random_player_die applied as throw-copy: ability=%s effect=%s dice=%s copies=%d" % [
						String(ability.ability_id),
						String(effect.effect_id),
						String(random_reroll_target.definition.dice_name) if random_reroll_target.definition != null else "unknown",
						rerolled_random.size(),
					]
				)
			else:
				_log_debug("reroll_random_player_die skipped: board throw-copy produced no dice")
			return reroll_success
	return false


static func _has_consumed_dice_with_name(consumed_dice: Array[Dice], expected_dice_name: StringName) -> bool:
	if expected_dice_name == &"":
		return false
	for dice in consumed_dice:
		if dice == null or not is_instance_valid(dice) or dice.definition == null:
			continue
		if StringName(dice.definition.dice_name) == expected_dice_name:
			return true
	return false


static func _reroll_remaining_player_dice(target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> bool:
	var reroll_targets: Array[Dice] = []
	for dice in _resolve_available_player_dice(target_descriptor):
		if _is_valid_reroll_candidate(dice, consumed_dice, reroll_targets):
			reroll_targets.append(dice)
	if reroll_targets.is_empty():
		_log_debug("kamikaze reroll skipped: no remaining player dice")
		return false
	var rerolled_dice := Dice.reroll_group_with_board_throw(reroll_targets)
	var success := not rerolled_dice.is_empty()
	if success:
		_log_debug("kamikaze reroll applied: source_count=%d rerolled_count=%d" % [reroll_targets.size(), rerolled_dice.size()])
	else:
		_log_debug("kamikaze reroll skipped: board reroll produced no dice")
	return success


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


static func _resolve_apply_status_target_descriptor(
	effect: AbilityEffectDefinition,
	target_descriptor: Dictionary,
	source_descriptor: Dictionary
) -> Dictionary:
	if effect == null:
		return _to_status_descriptor(target_descriptor)
	var target_kind := StringName(effect.parameters.get("target", &"target"))
	if target_kind == &"source":
		return _sanitize_status_descriptor(source_descriptor)
	return _to_status_descriptor(target_descriptor)


static func _sanitize_status_descriptor(raw_descriptor: Dictionary) -> Dictionary:
	var side := StringName(raw_descriptor.get("side", &""))
	if side == &"player":
		return {"side": &"player"}
	if side == &"enemy":
		return {
			"side": &"enemy",
			"index": int(raw_descriptor.get("index", -1)),
		}
	return {}


static func _resolve_reroll_dice_targets(
	effect: AbilityEffectDefinition,
	target_descriptor: Dictionary,
	consumed_dice: Array[Dice]
) -> Array[Dice]:
	var resolved: Array[Dice] = []
	var should_reroll_all_remaining := false
	if effect != null:
		should_reroll_all_remaining = StringName(effect.parameters.get("scope", &"")) == &"all_remaining_player_dice"
	if should_reroll_all_remaining:
		for dice in _resolve_available_player_dice(target_descriptor):
			if _is_valid_reroll_candidate(dice, consumed_dice, resolved):
				resolved.append(dice)

	var target_kind := StringName(target_descriptor.get("kind", &""))
	if target_kind == &"dice":
		var target_dice = target_descriptor.get("dice") as Dice
		if _is_valid_reroll_candidate(target_dice, consumed_dice, resolved, should_reroll_all_remaining):
			resolved.append(target_dice)
	for dice in consumed_dice:
		if _is_valid_reroll_candidate(dice, consumed_dice, resolved, false):
			resolved.append(dice)
	return resolved


static func _resolve_available_player_dice(target_descriptor: Dictionary) -> Array[Dice]:
	var resolved: Array[Dice] = []
	for raw_dice in target_descriptor.get("available_player_dice", []):
		if raw_dice is Dice and is_instance_valid(raw_dice):
			resolved.append(raw_dice as Dice)
	return resolved


static func _pick_random_reroll_candidate(target_descriptor: Dictionary, consumed_dice: Array[Dice]) -> Dice:
	var candidates: Array[Dice] = []
	for dice in _resolve_available_player_dice(target_descriptor):
		if _is_valid_reroll_candidate(dice, consumed_dice, candidates):
			candidates.append(dice)
	if candidates.is_empty():
		return null
	var selected_index := randi_range(0, candidates.size() - 1)
	return candidates[selected_index]


static func _passes_effect_chance(effect: AbilityEffectDefinition) -> bool:
	if effect == null:
		return false
	var resolved_chance := clampf(float(effect.chance), 0.0, 1.0)
	if resolved_chance >= 1.0:
		return true
	if resolved_chance <= 0.0:
		return false
	return randf() <= resolved_chance


static func _is_valid_reroll_candidate(
	candidate,
	consumed_dice: Array[Dice],
	already_selected: Array[Dice],
	exclude_consumed: bool = true
) -> bool:
	var dice := candidate as Dice
	if dice == null or not is_instance_valid(dice):
		return false
	if exclude_consumed and consumed_dice.has(dice):
		return false
	if already_selected.has(dice):
		return false
	return true


static func _log_debug(message: String) -> void:
	if not OS.is_debug_build():
		return
	print("[BattleEffectRuntime] %s" % message)
