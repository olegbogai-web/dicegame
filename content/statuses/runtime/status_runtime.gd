extends RefCounted
class_name StatusRuntime

const StatusContainer = preload("res://content/statuses/runtime/status_container.gd")

const OP_ADD := &"add"
const OP_MULTIPLY := &"multiply"
const OP_SET := &"set"

const TRIGGER_PASSIVE := &"passive"
const TRIGGER_TURN_START := &"on_turn_start"
const TRIGGER_TURN_END := &"on_turn_end"
const TRIGGER_ABILITY_BEFORE_RESOLVE := &"on_ability_before_resolve"
const TRIGGER_ABILITY_AFTER_RESOLVE := &"on_ability_after_resolve"
const TRIGGER_DAMAGE_TAKEN := &"on_damage_taken"
const TRIGGER_HEAL_TAKEN := &"on_heal_taken"

const EVENT_STATUS_APPLIED := &"status_applied"
const EVENT_STATUS_REMOVED := &"status_removed"
const EVENT_STATUS_TRIGGERED := &"status_triggered"
const EVENT_STATUS_EXPIRED := &"status_expired"


static func build_event_context(event_name: StringName, payload: Dictionary = {}) -> Dictionary:
	var context := {
		"event_name": event_name,
		"battle_room": payload.get("battle_room", null),
		"owner_descriptor": payload.get("owner_descriptor", {}),
		"source_descriptor": payload.get("source_descriptor", {}),
		"target_descriptor": payload.get("target_descriptor", {}),
		"ability": payload.get("ability", null),
		"ability_effect": payload.get("ability_effect", null),
		"magnitude": int(payload.get("magnitude", 0)),
		"metadata": payload.get("metadata", {}),
		"trigger_entries": [],
		"published_events": [],
	}
	if context["source_descriptor"].is_empty() and not context["owner_descriptor"].is_empty():
		context["source_descriptor"] = context["owner_descriptor"]
	return context


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


static func trigger_turn_start(battle_room, owner_descriptor: Dictionary) -> void:
	trigger_event(build_event_context(
		TRIGGER_TURN_START,
		{
			"battle_room": battle_room,
			"owner_descriptor": owner_descriptor,
		}
	))


static func trigger_turn_end(battle_room, owner_descriptor: Dictionary) -> void:
	trigger_event(build_event_context(
		TRIGGER_TURN_END,
		{
			"battle_room": battle_room,
			"owner_descriptor": owner_descriptor,
		}
	))


static func trigger_event(context: Dictionary) -> Dictionary:
	var battle_room = context.get("battle_room", null)
	if battle_room == null:
		return context
	var event_name := StringName(context.get("event_name", &""))
	if event_name == &"":
		return context
	var owner_descriptor := context.get("owner_descriptor", {}) as Dictionary
	if owner_descriptor.is_empty():
		owner_descriptor = context.get("target_descriptor", {}) as Dictionary
	if owner_descriptor.is_empty():
		owner_descriptor = context.get("source_descriptor", {}) as Dictionary
	if owner_descriptor.is_empty():
		return context

	var owner_container := _get_container_for_descriptor(battle_room, owner_descriptor)
	if owner_container == null:
		return context

	var owner_side := StringName(owner_descriptor.get("side", &""))
	var trigger_entries := _collect_effect_entries(
		[
			{
				"container": owner_container,
				"scope": owner_side,
			}
		],
		event_name,
		&""
	)
	trigger_entries.sort_custom(Callable(StatusRuntime, "_compare_effect_entries"))
	context["trigger_entries"] = trigger_entries

	for entry in trigger_entries:
		var effect := entry.get("effect") as StatusEffectDefinition
		if effect == null:
			continue
		_publish_status_event(context, EVENT_STATUS_TRIGGERED, {
			"trigger": event_name,
			"status_id": entry.get("status_id", &""),
			"effect_id": entry.get("effect_id", &""),
			"owner_descriptor": owner_descriptor,
		})
		_execute_trigger_effect(context, entry, effect)

	return context


static func clear_all_statuses(battle_room) -> void:
	if battle_room == null:
		return
	battle_room.clear_all_statuses()


static func apply_status(
	battle_room,
	target_descriptor: Dictionary,
	status_definition: StatusDefinition,
	stacks: int,
	source_descriptor: Dictionary = {}
) -> bool:
	if battle_room == null or status_definition == null:
		return false
	var container := _get_container_for_descriptor(battle_room, target_descriptor)
	if container == null:
		return false
	var previous_stacks := _get_status_stacks(container, StringName(status_definition.status_id))
	var instance := container.add_status(status_definition, maxi(stacks, 1))
	if instance == null:
		return false
	_publish_status_event(
		build_event_context(&"apply_status", {
			"battle_room": battle_room,
			"source_descriptor": source_descriptor,
			"target_descriptor": target_descriptor,
		}),
		EVENT_STATUS_APPLIED,
		{
			"status_id": StringName(status_definition.status_id),
			"target_descriptor": target_descriptor,
			"source_descriptor": source_descriptor,
			"previous_stacks": previous_stacks,
			"stacks": instance.stacks,
		}
	)
	return true


static func remove_status(
	battle_room,
	target_descriptor: Dictionary,
	status_id: StringName,
	stacks: int = -1,
	reason: StringName = EVENT_STATUS_REMOVED
) -> bool:
	if battle_room == null:
		return false
	var container := _get_container_for_descriptor(battle_room, target_descriptor)
	if container == null:
		return false
	var previous_stacks := _get_status_stacks(container, status_id)
	if previous_stacks <= 0:
		return false
	var removed := container.remove_status(status_id, stacks)
	if not removed:
		return false
	var current_stacks := _get_status_stacks(container, status_id)
	var event_name := reason if reason == EVENT_STATUS_EXPIRED else EVENT_STATUS_REMOVED
	_publish_status_event(
		build_event_context(event_name, {
			"battle_room": battle_room,
			"target_descriptor": target_descriptor,
		}),
		event_name,
		{
			"status_id": status_id,
			"target_descriptor": target_descriptor,
			"previous_stacks": previous_stacks,
			"stacks": current_stacks,
		}
	)
	return true


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
			var status_id = status_instance.get_status_id()
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
	context: Dictionary,
	entry: Dictionary,
	effect: StatusEffectDefinition
) -> void:
	if effect.effect_type == &"damage":
		_apply_direct_magnitude(context, effect, entry, true)
		return
	if effect.effect_type == &"heal":
		_apply_direct_magnitude(context, effect, entry, false)
		return
	if effect.effect_type == &"apply_status":
		_apply_status_to_scope(context, effect, entry)


static func _apply_direct_magnitude(
	context: Dictionary,
	effect: StatusEffectDefinition,
	entry: Dictionary,
	is_damage: bool
) -> void:
	var magnitude := maxi(int(round(float(entry.get("scaled_value", effect.value)))), 0)
	if magnitude <= 0:
		return
	var battle_room = context.get("battle_room", null)
	if battle_room == null:
		return
	var owner_descriptor := context.get("owner_descriptor", {}) as Dictionary
	var owner_side := StringName(owner_descriptor.get("side", &""))
	var targets := _resolve_targets(battle_room, owner_descriptor, owner_side, effect.target_scope)
	for target in targets:
		if StringName(target.get("side", &"")) == &"player":
			if is_damage:
				if not battle_room.apply_damage_to_descriptor({"side": &"player"}, magnitude):
					continue
				trigger_event(build_event_context(TRIGGER_DAMAGE_TAKEN, {
					"battle_room": battle_room,
					"owner_descriptor": target,
					"source_descriptor": owner_descriptor,
					"target_descriptor": target,
					"magnitude": magnitude,
					"metadata": {"origin": &"status"},
				}))
			else:
				if not battle_room.apply_heal_to_descriptor({"side": &"player"}, magnitude):
					continue
				trigger_event(build_event_context(TRIGGER_HEAL_TAKEN, {
					"battle_room": battle_room,
					"owner_descriptor": target,
					"source_descriptor": owner_descriptor,
					"target_descriptor": target,
					"magnitude": magnitude,
					"metadata": {"origin": &"status"},
				}))
			continue
		var monster_index := int(target.get("index", -1))
		var monster_descriptor := {"side": &"enemy", "index": monster_index}
		if is_damage:
			if not battle_room.apply_damage_to_descriptor(monster_descriptor, magnitude):
				continue
			trigger_event(build_event_context(TRIGGER_DAMAGE_TAKEN, {
				"battle_room": battle_room,
				"owner_descriptor": target,
				"source_descriptor": owner_descriptor,
				"target_descriptor": target,
				"magnitude": magnitude,
				"metadata": {"origin": &"status"},
			}))
			continue
		if not battle_room.apply_heal_to_descriptor(monster_descriptor, magnitude):
			continue
		trigger_event(build_event_context(TRIGGER_HEAL_TAKEN, {
			"battle_room": battle_room,
			"owner_descriptor": target,
			"source_descriptor": owner_descriptor,
			"target_descriptor": target,
			"magnitude": magnitude,
			"metadata": {"origin": &"status"},
		}))


static func _apply_status_to_scope(
	context: Dictionary,
	effect: StatusEffectDefinition,
	entry: Dictionary
) -> void:
	if effect.status_id.is_empty():
		return
	var status_definition := _resolve_status_definition(effect.parameters)
	if status_definition == null:
		return
	var battle_room = context.get("battle_room", null)
	if battle_room == null:
		return
	var owner_descriptor := context.get("owner_descriptor", {}) as Dictionary
	var owner_side := StringName(owner_descriptor.get("side", &""))
	var entry_stacks := int(entry.get("stacks", 1))
	var resolved_stacks := maxi(int(effect.parameters.get("stacks", entry_stacks)), 1)
	for target in _resolve_targets(battle_room, owner_descriptor, owner_side, effect.target_scope):
		apply_status(battle_room, target, status_definition, resolved_stacks, owner_descriptor)


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
	return battle_room.get_status_container_for_descriptor(descriptor)


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


static func _publish_status_event(context: Dictionary, event_name: StringName, payload: Dictionary = {}) -> void:
	var battle_room = context.get("battle_room", null)
	var event_payload := {
		"event_name": event_name,
		"payload": payload,
	}
	var buffer = context.get("published_events", null)
	if buffer is Array:
		buffer.append(event_payload)
	if battle_room != null and battle_room.has_method("publish_status_event"):
		battle_room.publish_status_event(event_name, payload)


static func _get_status_stacks(container: StatusContainer, status_id: StringName) -> int:
	if container == null:
		return 0
	var instance := container.get_status(status_id)
	if instance == null or not instance.is_effectively_active():
		return 0
	return instance.stacks
