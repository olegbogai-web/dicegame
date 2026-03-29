extends RefCounted
class_name BattleEffectRuntime

const BattleTurnRuntime = preload("res://content/combat/runtime/battle_turn_runtime.gd")
const Dice = preload("res://content/dice/dice.gd")
const StatusRuntime = preload("res://content/statuses/runtime/status_runtime.gd")


static func activate_current_turn_ability(battle_room, ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	if ability == null or battle_room.current_turn_owner == &"none" or BattleTurnRuntime.is_battle_over(battle_room):
		return {
			"success": false,
			"affected_targets": [],
			"battle_finished": BattleTurnRuntime.is_battle_over(battle_room),
		}

	var affected_targets: Array[Dictionary] = []
	var consumed_dice: Array[Dice] = []
	for raw_dice in target_descriptor.get("consumed_dice", []):
		if raw_dice is Dice:
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

	StatusRuntime.trigger_event(StatusRuntime.build_event_context(
		StatusRuntime.TRIGGER_ABILITY_AFTER_RESOLVE,
		{
			"battle_room": battle_room,
			"owner_descriptor": source_descriptor,
			"source_descriptor": source_descriptor,
			"ability": ability,
			"metadata": {
				"affected_targets": affected_targets,
			},
		}
	))

	BattleTurnRuntime.update_battle_result_if_finished(battle_room)
	return {
		"success": true,
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
				battle_room.monster_views[monster_index].take_damage(resolved_magnitude)
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
				if battle_room.player_instance != null:
					battle_room.player_instance.take_damage(resolved_magnitude)
				if battle_room.player_view != null:
					battle_room.player_view.take_damage(resolved_magnitude)
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
				if battle_room.player_instance != null:
					battle_room.player_instance.heal(resolved_magnitude)
				if battle_room.player_view != null:
					battle_room.player_view.heal(resolved_magnitude)
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
				battle_room.monster_views[monster_index].heal(resolved_magnitude)
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
				return false
			var status_stacks := maxi(int(effect.parameters.get("stacks", 1)), 1)
			var status_target := _to_status_descriptor(target_descriptor)
			if status_target.is_empty():
				return false
			return StatusRuntime.apply_status(battle_room, status_target, status_definition, status_stacks, source_descriptor)
	return false


static func _resolve_source_status_container(battle_room):
	if battle_room.current_turn_owner == &"player":
		if battle_room.player_view == null:
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
