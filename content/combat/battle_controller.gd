extends RefCounted
class_name BattleController

const BattleStateScript = preload("res://content/combat/battle_state.gd")
const CombatantStateScript = preload("res://content/combat/combatant_state.gd")
const TurnStateScript = preload("res://content/combat/turn_state.gd")

signal battle_started(state: BattleState)
signal battle_state_changed(state: BattleState)
signal turn_started(combatant: CombatantState, turn_state: TurnState)
signal player_dice_requested(dice_count: int)
signal player_action_required(combatant: CombatantState, turn_state: TurnState)
signal log_emitted(message: String)
signal battle_ended(result_code: StringName, state: BattleState)

var battle_state: BattleState
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func setup_battle(player: Player, player_sprite: Texture2D, monsters: Array[MonsterDefinition]) -> BattleState:
	battle_state = BattleStateScript.new()
	battle_state.battle_id = StringName("battle_%d" % Time.get_unix_time_from_system())
	battle_state.round_index = 1
	battle_state.battle_phase = &"setup"
	battle_state.combatants = _build_combatants(player, player_sprite, monsters)
	return battle_state


func start_battle() -> void:
	if battle_state == null or battle_state.combatants.is_empty():
		return
	battle_state.battle_phase = &"active"
	emit_signal("battle_started", battle_state)
	emit_signal("log_emitted", "Бой начался. Первый ход за игроком.")
	emit_signal("battle_state_changed", battle_state)
	_start_player_turn()


func sync_player_dice(dice_entries: Array[Dictionary]) -> void:
	if battle_state == null or battle_state.is_finished:
		return
	var active_combatant := get_active_combatant()
	if active_combatant == null or not active_combatant.is_player():
		return
	battle_state.active_turn.dice_pool.set_rolled_dice(dice_entries)


func end_player_turn() -> void:
	if battle_state == null or battle_state.is_finished:
		return
	var active_combatant := get_active_combatant()
	if active_combatant == null or not active_combatant.is_player():
		return
	_finish_turn(&"player_ended_turn")
	_process_enemy_round()


func activate_player_ability(
	ability: AbilityDefinition,
	target_id: StringName,
	selected_dice_ids: Array[StringName]
) -> Dictionary:
	var response := {
		"success": false,
		"message": "",
		"consumed_dice_ids": [],
	}
	if battle_state == null or battle_state.is_finished:
		response["message"] = "Бой не активен."
		return response

	var source := get_active_combatant()
	if source == null or not source.is_player():
		response["message"] = "Сейчас не ход игрока."
		return response

	var resolved_target_ids := _resolve_target_ids(source, ability, target_id)
	if resolved_target_ids.is_empty():
		response["message"] = "Не выбрана корректная цель."
		return response

	if not can_activate_ability(source, ability, selected_dice_ids):
		response["message"] = "Нельзя активировать способность с выбранными кубами."
		return response

	var consumed := battle_state.active_turn.dice_pool.spend_dice(selected_dice_ids)
	_apply_ability(source, ability, resolved_target_ids, consumed)
	battle_state.active_turn.mark_ability_used(StringName(ability.ability_id))
	response["success"] = true
	response["message"] = "Способность применена."
	response["consumed_dice_ids"] = selected_dice_ids
	emit_signal("battle_state_changed", battle_state)

	if battle_state.is_finished:
		return response

	if not _has_available_player_action(source):
		emit_signal("log_emitted", "У игрока не осталось доступных действий. Ход завершен автоматически.")
		_finish_turn(&"player_no_actions")
		_process_enemy_round()
	else:
		emit_signal("player_action_required", source, battle_state.active_turn)

	return response


func get_active_combatant() -> CombatantState:
	if battle_state == null:
		return null
	return battle_state.get_combatant(battle_state.active_combatant_id)


func _build_combatants(player: Player, player_sprite: Texture2D, monsters: Array[MonsterDefinition]) -> Array[CombatantState]:
	var combatants: Array[CombatantState] = []
	if player != null:
		var player_combatant := CombatantStateScript.new()
		player_combatant.combatant_id = &"player"
		player_combatant.display_name = player.base_stat.display_name if player.base_stat != null else "Игрок"
		player_combatant.side = CombatantStateScript.Side.PLAYER
		player_combatant.current_hp = player.current_hp
		player_combatant.max_hp = player.base_stat.max_hp if player.base_stat != null else player.current_hp
		player_combatant.dice_count = player.dice_loadout.size()
		player_combatant.abilities = player.ability_loadout.duplicate()
		player_combatant.sprite = player_sprite
		player_combatant.metadata = {"source_player": player}
		combatants.append(player_combatant)

	for index in monsters.size():
		var monster_definition := monsters[index]
		if monster_definition == null:
			continue
		var monster := CombatantStateScript.new()
		monster.combatant_id = StringName("enemy_%d_%s" % [index, monster_definition.monster_id])
		monster.display_name = monster_definition.display_name
		monster.side = CombatantStateScript.Side.ENEMY
		monster.current_hp = monster_definition.max_health
		monster.max_hp = monster_definition.max_health
		monster.dice_count = monster_definition.dice_count
		monster.abilities = monster_definition.abilities.duplicate()
		monster.sprite = monster_definition.sprite
		monster.spawn_index = index
		monster.metadata = {"definition": monster_definition}
		combatants.append(monster)
	return combatants


func _start_player_turn() -> void:
	var player := battle_state.get_player()
	if player == null or not player.is_alive():
		_set_battle_result(&"player_defeat", &"player_dead")
		return

	battle_state.active_combatant_id = player.combatant_id
	battle_state.battle_phase = &"player_turn"
	battle_state.active_turn = TurnStateScript.new()
	battle_state.active_turn.configure(player.combatant_id, battle_state.round_index, [])
	emit_signal("log_emitted", "Ход игрока. Бросьте %d куб(а/ов)." % player.dice_count)
	emit_signal("turn_started", player, battle_state.active_turn)
	emit_signal("player_dice_requested", player.dice_count)
	emit_signal("player_action_required", player, battle_state.active_turn)
	emit_signal("battle_state_changed", battle_state)


func _process_enemy_round() -> void:
	if _check_battle_finished():
		return

	var enemies := battle_state.get_alive_enemies()
	enemies.sort_custom(func(a: CombatantState, b: CombatantState) -> bool:
		if a.dice_count == b.dice_count:
			return a.spawn_index < b.spawn_index
		return a.dice_count > b.dice_count
	)

	for enemy in enemies:
		if battle_state.is_finished:
			break
		if enemy == null or not enemy.is_alive():
			continue
		_run_enemy_turn(enemy)

	if battle_state.is_finished:
		return
	battle_state.round_index += 1
	_start_player_turn()


func _run_enemy_turn(enemy: CombatantState) -> void:
	battle_state.active_combatant_id = enemy.combatant_id
	battle_state.battle_phase = &"enemy_turn"
	battle_state.active_turn = TurnStateScript.new()
	battle_state.active_turn.configure(enemy.combatant_id, battle_state.round_index, _roll_ai_dice(enemy))
	emit_signal("log_emitted", "Ход %s." % enemy.display_name)
	emit_signal("turn_started", enemy, battle_state.active_turn)
	emit_signal("battle_state_changed", battle_state)

	var ai_action := _build_ai_action(enemy)
	if ai_action.is_empty():
		emit_signal("log_emitted", "%s не нашел подходящее действие и завершил ход." % enemy.display_name)
		_finish_turn(&"enemy_no_action")
		return

	var ability := ai_action["ability"] as AbilityDefinition
	var target_ids: Array[StringName] = ai_action["target_ids"]
	var selected_dice_ids: Array[StringName] = ai_action["selected_dice_ids"]
	var consumed := battle_state.active_turn.dice_pool.spend_dice(selected_dice_ids)
	_apply_ability(enemy, ability, target_ids, consumed)
	battle_state.active_turn.mark_ability_used(StringName(ability.ability_id))
	_finish_turn(&"enemy_action_resolved")


func _build_ai_action(source: CombatantState) -> Dictionary:
	for ability in source.abilities:
		if ability == null or not ability.is_active():
			continue
		var selected_dice_ids := _pick_dice_for_ability(ability, battle_state.active_turn.dice_pool)
		if ability.cost != null and ability.cost.requires_dice() and selected_dice_ids.is_empty():
			continue
		var target_ids := _resolve_target_ids(source, ability, &"")
		if target_ids.is_empty():
			continue
		return {
			"ability": ability,
			"target_ids": target_ids,
			"selected_dice_ids": selected_dice_ids,
		}
	return {}


func _pick_dice_for_ability(ability: AbilityDefinition, dice_pool) -> Array[StringName]:
	var selected_ids: Array[StringName] = []
	if ability == null or ability.cost == null or not ability.cost.requires_dice():
		return selected_ids

	var available := dice_pool.get_available_dice()
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		var matched_for_condition: Array[StringName] = []
		for die_entry in available:
			var die_id := die_entry["id"] as StringName
			if selected_ids.has(die_id):
				continue
			if not _die_entry_matches_condition(die_entry, dice_condition):
				continue
			if not _die_entry_satisfies_use_conditions(die_entry, ability):
				continue
			matched_for_condition.append(die_id)
			if matched_for_condition.size() >= dice_condition.required_count:
				break
		if matched_for_condition.size() < dice_condition.required_count:
			return []
		selected_ids.append_array(matched_for_condition)
	return selected_ids


func can_activate_ability(source: CombatantState, ability: AbilityDefinition, selected_dice_ids: Array[StringName]) -> bool:
	if source == null or ability == null or battle_state.active_turn == null:
		return false
	if not source.abilities.has(ability):
		return false
	if ability.cost != null and ability.cost.requires_dice():
		if not battle_state.active_turn.dice_pool.are_dice_available(selected_dice_ids):
			return false
		return _selected_dice_match_ability(ability, selected_dice_ids)
	return selected_dice_ids.is_empty()


func _selected_dice_match_ability(ability: AbilityDefinition, selected_dice_ids: Array[StringName]) -> bool:
	if ability == null or ability.cost == null:
		return selected_dice_ids.is_empty()
	var remaining_ids := selected_dice_ids.duplicate()
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		var matched_count := 0
		var used_ids: Array[StringName] = []
		for die_id in remaining_ids:
			var die_entry := battle_state.active_turn.dice_pool.get_die_entry(die_id)
			if die_entry.is_empty():
				continue
			if not _die_entry_matches_condition(die_entry, dice_condition):
				continue
			if not _die_entry_satisfies_use_conditions(die_entry, ability):
				continue
			used_ids.append(die_id)
			matched_count += 1
			if matched_count >= dice_condition.required_count:
				break
		if matched_count < dice_condition.required_count:
			return false
		for used_id in used_ids:
			remaining_ids.erase(used_id)
	return remaining_ids.is_empty()


func _die_entry_matches_condition(die_entry: Dictionary, dice_condition: AbilityDiceCondition) -> bool:
	var value := int(die_entry.get("value", -1))
	if not dice_condition.matches_value(value):
		return false

	var face_id := String(die_entry.get("face_id", ""))
	if dice_condition.requires_face_filter() and not dice_condition.accepted_face_ids.has(face_id):
		return false

	var tags := PackedStringArray(die_entry.get("tags", PackedStringArray()))
	for required_tag in dice_condition.required_tags:
		if not tags.has(required_tag):
			return false
	for forbidden_tag in dice_condition.forbidden_tags:
		if tags.has(forbidden_tag):
			return false
	return true


func _die_entry_satisfies_use_conditions(die_entry: Dictionary, ability: AbilityDefinition) -> bool:
	for condition in ability.use_conditions:
		if condition == null:
			continue
		if condition.predicate == &"selected_die_top_face_parity":
			var parity := String(condition.parameters.get("parity", ""))
			var value := int(die_entry.get("value", -1))
			if parity == "even" and value % 2 != 0:
				return false
			if parity == "odd" and value % 2 == 0:
				return false
	return true


func _resolve_target_ids(source: CombatantState, ability: AbilityDefinition, explicit_target_id: StringName) -> Array[StringName]:
	var target_ids: Array[StringName] = []
	if source == null or ability == null or ability.target_rule == null:
		return target_ids

	var target_rule := ability.target_rule
	if target_rule.selection == AbilityTargetRule.Selection.NONE or target_rule.allow_self:
		if target_rule.selection == AbilityTargetRule.Selection.NONE:
			target_ids.append(source.combatant_id)
			return target_ids
		if explicit_target_id == &"" and target_rule.allow_self and target_rule.max_targets == 0:
			target_ids.append(source.combatant_id)
			return target_ids

	if target_rule.selection == AbilityTargetRule.Selection.ALL:
		for target in _get_default_targets_for_side(source, ability):
			target_ids.append(target.combatant_id)
		return target_ids

	if explicit_target_id != &"":
		var explicit_target := battle_state.get_combatant(explicit_target_id)
		if _is_valid_target(source, ability, explicit_target):
			target_ids.append(explicit_target_id)
		return target_ids

	for target in _get_default_targets_for_side(source, ability):
		if _is_valid_target(source, ability, target):
			target_ids.append(target.combatant_id)
			break
	return target_ids


func _get_default_targets_for_side(source: CombatantState, ability: AbilityDefinition) -> Array[CombatantState]:
	if source == null:
		return []
	if ability != null and ability.target_rule != null and ability.target_rule.allow_self:
		return battle_state.get_alive_allies(source)
	if source.is_player():
		return battle_state.get_alive_enemies()
	var player := battle_state.get_player()
	return [player] if player != null and player.is_alive() else []


func _is_valid_target(source: CombatantState, ability: AbilityDefinition, target: CombatantState) -> bool:
	if source == null or ability == null or target == null:
		return false
	if not target.is_alive() and not ability.target_rule.can_target_dead:
		return false
	if target.combatant_id == source.combatant_id:
		return ability.target_rule.allow_self or ability.target_rule.selection == AbilityTargetRule.Selection.NONE
	return source.side != target.side or ability.target_rule.selection == AbilityTargetRule.Selection.ALL


func _apply_ability(
	source: CombatantState,
	ability: AbilityDefinition,
	target_ids: Array[StringName],
	consumed_dice: Array[Dictionary]
) -> void:
	var target_names: Array[String] = []
	for target_id in target_ids:
		var target := battle_state.get_combatant(target_id)
		if target != null:
			target_names.append(target.display_name)
	var target_suffix := ""
	if not target_names.is_empty():
		target_suffix = " по %s" % ", ".join(target_names)
	emit_signal("log_emitted", "%s использует %s%s." % [source.display_name, ability.display_name, target_suffix])

	for effect in ability.effects:
		if effect == null:
			continue
		for repeat_index in maxi(effect.repeat_count, 1):
			if _rng.randf() > clampf(effect.chance, 0.0, 1.0):
				continue
			_apply_effect(source, effect, target_ids, consumed_dice)
			if _check_battle_finished():
				return


func _apply_effect(
	source: CombatantState,
	effect: AbilityEffectDefinition,
	target_ids: Array[StringName],
	_consumed_dice: Array[Dictionary]
) -> void:
	match String(effect.effect_type):
		"damage":
			for target_id in target_ids:
				var target := battle_state.get_combatant(target_id)
				if target == null:
					continue
				var damage_done := target.take_damage(effect.magnitude)
				emit_signal("log_emitted", "%s получает %d урона." % [target.display_name, damage_done])
		"healing":
			for target_id in target_ids:
				var target := battle_state.get_combatant(target_id)
				if target == null:
					continue
				var healed_amount := target.heal(effect.magnitude)
				emit_signal("log_emitted", "%s восстанавливает %d HP." % [target.display_name, healed_amount])
		_:
			emit_signal("log_emitted", "Эффект %s пока не поддерживается." % String(effect.effect_type))


func _check_battle_finished() -> bool:
	if battle_state == null or battle_state.is_finished:
		return battle_state != null and battle_state.is_finished
	var player := battle_state.get_player()
	if player == null or not player.is_alive():
		_set_battle_result(&"player_defeat", &"player_dead")
		return true
	if battle_state.get_alive_enemies().is_empty():
		_set_battle_result(&"player_victory", &"all_monsters_dead")
		return true
	return false


func _set_battle_result(result_code: StringName, reason: StringName) -> void:
	if battle_state == null or battle_state.is_finished:
		return
	battle_state.battle_phase = &"finished"
	battle_state.set_result(result_code, reason)
	var result_message := "Победа игрока." if result_code == &"player_victory" else "Игрок проиграл."
	emit_signal("log_emitted", result_message)
	emit_signal("battle_state_changed", battle_state)
	emit_signal("battle_ended", result_code, battle_state)


func _finish_turn(reason: StringName) -> void:
	if battle_state == null or battle_state.active_turn == null:
		return
	battle_state.active_turn.finish(reason)
	emit_signal("battle_state_changed", battle_state)


func _has_available_player_action(player: CombatantState) -> bool:
	if player == null:
		return false
	for ability in player.abilities:
		if ability == null or not ability.is_active():
			continue
		if ability.cost == null or not ability.cost.requires_dice():
			return true
		if not _pick_dice_for_ability(ability, battle_state.active_turn.dice_pool).is_empty():
			return true
	return false


func _roll_ai_dice(combatant: CombatantState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in combatant.dice_count:
		var value := _rng.randi_range(1, 6)
		entries.append({
			"id": StringName("%s_die_%d" % [combatant.combatant_id, index]),
			"value": value,
			"tags": PackedStringArray(["base_cube", String.num_int64(value)]),
			"face_id": StringName(String.num_int64(value)),
		})
	return entries
