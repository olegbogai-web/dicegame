extends RefCounted
class_name BattleEffectRuntime

const BattleTurnRuntime = preload("res://content/combat/runtime/battle_turn_runtime.gd")


static func activate_current_turn_ability(battle_room, ability: AbilityDefinition, target_descriptor: Dictionary) -> Dictionary:
	if ability == null or battle_room.current_turn_owner == &"none" or BattleTurnRuntime.is_battle_over(battle_room):
		return {
			"success": false,
			"affected_targets": [],
			"battle_finished": BattleTurnRuntime.is_battle_over(battle_room),
		}

	var affected_targets: Array[Dictionary] = []
	for effect in ability.effects:
		if effect == null:
			continue
		var effect_targets := _resolve_effect_targets(battle_room, target_descriptor)
		for effect_target in effect_targets:
			if _apply_effect_to_target(battle_room, effect, effect_target):
				affected_targets.append(effect_target)

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


static func _apply_effect_to_target(battle_room, effect: AbilityEffectDefinition, target_descriptor: Dictionary) -> bool:
	var target_kind := StringName(target_descriptor.get("kind", &""))
	match effect.effect_type:
		&"damage":
			if target_kind == &"monster":
				var monster_index := int(target_descriptor.get("index", -1))
				if not battle_room.can_target_monster(monster_index):
					return false
				battle_room.monster_views[monster_index].take_damage(effect.magnitude)
				return true
			if target_kind == &"player":
				if battle_room.player_instance != null:
					battle_room.player_instance.take_damage(effect.magnitude)
				if battle_room.player_view != null:
					battle_room.player_view.take_damage(effect.magnitude)
				return true
		&"healing":
			if target_kind == &"player":
				if battle_room.player_instance != null:
					battle_room.player_instance.heal(effect.magnitude)
				if battle_room.player_view != null:
					battle_room.player_view.heal(effect.magnitude)
				return true
			if target_kind == &"monster":
				var monster_index := int(target_descriptor.get("index", -1))
				if not battle_room.can_target_monster(monster_index):
					return false
				battle_room.monster_views[monster_index].heal(effect.magnitude)
				return true
	return false
