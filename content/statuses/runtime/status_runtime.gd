extends RefCounted
class_name StatusRuntime

const StatusContainer = preload("res://content/statuses/runtime/status_container.gd")

const OP_ADD := &"add"
const OP_MULTIPLY := &"multiply"
const OP_SET := &"set"

const TRIGGER_PASSIVE := &"passive"
const TRIGGER_TURN_END := &"on_turn_end"


static func resolve_ability_effect_magnitude(
	effect: AbilityEffectDefinition,
	consumed_dice,
	source_container: StatusContainer,
	target_container: StatusContainer
) -> int:
	if effect == null:
		return 0

	var selected_die_multiplier := int(effect.parameters.get("selected_die_multiplier", 0))
	if selected_die_multiplier != 0 and consumed_dice is Array and not consumed_dice.is_empty():
		var selected_die = consumed_dice[0]
		if selected_die != null and is_instance_valid(selected_die):
			var selected_die_value := maxi(selected_die.get_top_face_value(), 0)
			var die_result := resolve_passive_modifier_pipeline(
				selected_die_value,
				[
					{"container": source_container, "stat_key": &"dice_face_value_outgoing", "scope": &"source"},
				]
			)
			return maxi(die_result.get("value", 0), 0) * selected_die_multiplier

	if effect.effect_type == &"damage":
		var damage_result := resolve_passive_modifier_pipeline(
			effect.magnitude,
			[
				{"container": source_container, "stat_key": &"ability_damage_outgoing", "scope": &"source"},
				{"container": target_container, "stat_key": &"ability_damage_incoming", "scope": &"target"},
			]
		)
		return maxi(damage_result.get("value", 0), 0)

	if effect.effect_type == &"healing":
		var healing_result := resolve_passive_modifier_pipeline(
			effect.magnitude,
			[
				{"container": source_container, "stat_key": &"ability_healing_outgoing", "scope": &"source"},
				{"container": target_container, "stat_key": &"ability_healing_incoming", "scope": &"target"},
			]
		)
		return maxi(healing_result.get("value", 0), 0)

	return maxi(effect.magnitude, 0)


static func resolve_passive_modifier_pipeline(base_value: int, modifier_queries: Array[Dictionary]) -> Dictionary:
	var resolved_entries := _collect_effect_entries(modifier_queries, TRIGGER_PASSIVE, &"modifier")
	if resolved_entries.is_empty():
		return {
			"value": maxi(base_value, 0),
			"entries": [],
			"pipeline": {
				"set": [],
				"add": [],
				"multiply": [],
			},
		}

	resolved_entries.sort_custom(Callable(StatusRuntime, "_compare_effect_entries"))
	var execution_result := _apply_modifier_entries(base_value, resolved_entries)
	execution_result["entries"] = resolved_entries
	return execution_result


static func trigger_turn_end(battle_room, owner_descriptor: Dictionary) -> void:
	var owner_container := _get_container_for_descriptor(battle_room, owner_descriptor)
	if owner_container == null:
		return
	var owner_side := StringName(owner_descriptor.get("side", &""))
	var trigger_entries := _collect_effect_entries(
		[
			{
				"container": owner_container,
				"scope": owner_side,
			}
		],
		TRIGGER_TURN_END,
		&""
	)
	trigger_entries.sort_custom(Callable(StatusRuntime, "_compare_effect_entries"))

	for entry in trigger_entries:
		var effect := entry.get("effect") as StatusEffectDefinition
		if effect == null:
			continue
		_execute_trigger_effect(battle_room, owner_descriptor, owner_side, entry, effect)


static func clear_all_statuses(battle_room) -> void:
	if battle_room == null:
		return
	if battle_room.player_view != null and battle_room.player_view.statuses != null:
		battle_room.player_view.statuses.clear()
	for monster_view in battle_room.monster_views:
		if monster_view != null and monster_view.statuses != null:
			monster_view.statuses.clear()


static func _collect_effect_entries(
	queries: Array[Dictionary],
	trigger: StringName,
	effect_type: StringName
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for query_index in queries.size():
		var query := queries[query_index]
		var container := query.get("container") as StatusContainer
		if container == null:
			continue
		var stat_key := StringName(query.get("stat_key", &""))
		var scope := StringName(query.get("scope", &""))
		for status_instance in _get_sorted_active_statuses(container):
			if status_instance == null or status_instance.definition == null:
				continue
			var status_id := status_instance.get_status_id()
			for effect in status_instance.definition.effects:
				if effect == null:
					continue
				if effect.trigger != trigger:
					continue
				if effect_type != &"" and effect.effect_type != effect_type:
					continue
				if effect_type == &"modifier" and effect.stat_key != stat_key:
					continue
				entries.append({
					"effect": effect,
					"status_id": status_id,
					"effect_id": StringName(effect.effect_id),
					"operation": effect.operation,
					"scaled_value": effect.value * float(status_instance.stacks),
					"stacks": status_instance.stacks,
					"priority": effect.priority,
					"phase_order": effect.phase_order,
					"query_index": query_index,
					"scope": scope,
				})
	return entries


static func _compare_effect_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_priority := int(left.get("priority", 0))
	var right_priority := int(right.get("priority", 0))
	if left_priority != right_priority:
		return left_priority > right_priority
	var left_phase_order := int(left.get("phase_order", 0))
	var right_phase_order := int(right.get("phase_order", 0))
	if left_phase_order != right_phase_order:
		return left_phase_order < right_phase_order
	var left_query := int(left.get("query_index", 0))
	var right_query := int(right.get("query_index", 0))
	if left_query != right_query:
		return left_query < right_query
	var left_status_id := String(left.get("status_id", &""))
	var right_status_id := String(right.get("status_id", &""))
	if left_status_id != right_status_id:
		return left_status_id < right_status_id
	var left_effect_id := String(left.get("effect_id", &""))
	var right_effect_id := String(right.get("effect_id", &""))
	if left_effect_id != right_effect_id:
		return left_effect_id < right_effect_id
	return String(left.get("operation", &"")) < String(right.get("operation", &""))


static func _apply_modifier_entries(base_value: int, sorted_entries: Array[Dictionary]) -> Dictionary:
	var set_entries: Array[Dictionary] = []
	var add_entries: Array[Dictionary] = []
	var multiply_entries: Array[Dictionary] = []
	for entry in sorted_entries:
		var operation := StringName(entry.get("operation", OP_ADD))
		match operation:
			OP_SET:
				set_entries.append(entry)
			OP_MULTIPLY:
				multiply_entries.append(entry)
			_:
				add_entries.append(entry)

	var resolved_value := float(base_value)
	if not set_entries.is_empty():
		resolved_value = float(set_entries[-1].get("scaled_value", resolved_value))
	for entry in add_entries:
		resolved_value += float(entry.get("scaled_value", 0.0))
	for entry in multiply_entries:
		resolved_value *= maxf(float(entry.get("scaled_value", 1.0)), 0.0)

	return {
		"value": maxi(int(round(resolved_value)), 0),
		"pipeline": {
			"set": set_entries,
			"add": add_entries,
			"multiply": multiply_entries,
		},
	}


static func _execute_trigger_effect(
	battle_room,
	owner_descriptor: Dictionary,
	owner_side: StringName,
	entry: Dictionary,
	effect: StatusEffectDefinition
) -> void:
	if effect.effect_type == &"damage":
		_apply_direct_magnitude(battle_room, owner_descriptor, owner_side, effect, entry, true)
		return
	if effect.effect_type == &"heal":
		_apply_direct_magnitude(battle_room, owner_descriptor, owner_side, effect, entry, false)
		return
	if effect.effect_type == &"apply_status":
		_apply_status_to_scope(battle_room, owner_descriptor, owner_side, effect, entry)


static func _apply_direct_magnitude(
	battle_room,
	owner_descriptor: Dictionary,
	owner_side: StringName,
	effect: StatusEffectDefinition,
	entry: Dictionary,
	is_damage: bool
) -> void:
	var magnitude := maxi(int(round(float(entry.get("scaled_value", effect.value)))), 0)
	if magnitude <= 0:
		return
	var targets := _resolve_targets(battle_room, owner_descriptor, owner_side, effect.target_scope)
	for target in targets:
		if StringName(target.get("side", &"")) == &"player":
			if battle_room.player_view == null:
				continue
			if is_damage:
				battle_room.player_view.take_damage(magnitude)
			else:
				battle_room.player_view.heal(magnitude)
			continue
		var monster_index := int(target.get("index", -1))
		if not battle_room.can_target_monster(monster_index):
			continue
		if is_damage:
			battle_room.monster_views[monster_index].take_damage(magnitude)
		else:
			battle_room.monster_views[monster_index].heal(magnitude)


static func _apply_status_to_scope(
	battle_room,
	owner_descriptor: Dictionary,
	owner_side: StringName,
	effect: StatusEffectDefinition,
	entry: Dictionary
) -> void:
	if effect.status_id.is_empty():
		return
	var status_definition := _resolve_status_definition(effect.parameters)
	if status_definition == null:
		return
	var entry_stacks := int(entry.get("stacks", 1))
	var resolved_stacks := maxi(int(effect.parameters.get("stacks", entry_stacks)), 1)
	for target in _resolve_targets(battle_room, owner_descriptor, owner_side, effect.target_scope):
		var container := _get_container_for_descriptor(battle_room, target)
		if container != null:
			container.add_status(status_definition, resolved_stacks)


static func _resolve_targets(battle_room, owner_descriptor: Dictionary, owner_side: StringName, target_scope: StringName) -> Array[Dictionary]:
	if target_scope == &"self":
		return [owner_descriptor]
	if target_scope == &"all_enemies":
		if owner_side == &"player":
			var monsters: Array[Dictionary] = []
			for monster_index in battle_room.get_living_monster_indexes():
				monsters.append({"side": &"enemy", "index": monster_index})
			return monsters
		if battle_room.can_target_player():
			return [{"side": &"player"}]
		return []
	if target_scope == &"random_enemy":
		var enemies := _resolve_targets(battle_room, owner_descriptor, owner_side, &"all_enemies")
		if enemies.is_empty():
			return []
		return [enemies[randi() % enemies.size()]]
	return [owner_descriptor]


static func _resolve_status_definition(parameters: Dictionary) -> StatusDefinition:
	if parameters.has("status_definition") and parameters["status_definition"] is StatusDefinition:
		return parameters["status_definition"] as StatusDefinition
	return null


static func _get_container_for_descriptor(battle_room, descriptor: Dictionary) -> StatusContainer:
	var side := StringName(descriptor.get("side", &""))
	if side == &"player":
		if battle_room.player_view == null:
			return null
		return battle_room.player_view.statuses
	if side == &"enemy":
		var monster_index := int(descriptor.get("index", -1))
		if monster_index < 0 or monster_index >= battle_room.monster_views.size():
			return null
		var monster_view = battle_room.monster_views[monster_index]
		if monster_view == null:
			return null
		return monster_view.statuses
	return null


static func _get_sorted_active_statuses(container: StatusContainer) -> Array:
	if container == null:
		return []
	var statuses: Array = []
	for status_instance in container.get_active_statuses():
		statuses.append(status_instance)
	statuses.sort_custom(func(left, right) -> bool:
		if left == null or right == null:
			return left != null
		return String(left.get_status_id()) < String(right.get_status_id())
	)
	return statuses
