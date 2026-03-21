extends RefCounted
class_name CombatService

const CombatEnums = preload("res://content/combat/resources/combat_enums.gd")
const BattleActionIntent = preload("res://content/combat/runtime/battle_action_intent.gd")
const BattleResult = preload("res://content/combat/runtime/battle_result.gd")
const BattleState = preload("res://content/combat/runtime/battle_state.gd")
const CombatantRuntime = preload("res://content/combat/runtime/combatant_runtime.gd")
const MonsterAiPolicy = preload("res://content/combat/services/monster_ai_policy.gd")
const TurnDie = preload("res://content/combat/runtime/turn_die.gd")
const TurnState = preload("res://content/combat/runtime/turn_state.gd")
const Player = preload("res://content/entities/player.gd")
const MonsterDefinition = preload("res://content/monsters/resources/monster_definition.gd")
const DiceDefinition = preload("res://content/dice/resources/dice_definition.gd")
const AbilityCondition = preload("res://content/abilities/resources/ability_condition.gd")
const AbilityEffectDefinition = preload("res://content/abilities/resources/ability_effect_definition.gd")
const AbilityTargetRule = preload("res://content/abilities/resources/ability_target_rule.gd")

var monster_ai: MonsterAiPolicy = MonsterAiPolicy.new()
var _battle_sequence := 0


func create_battle_state(player: Player, monsters: Array[MonsterDefinition], source_room_id: String = "") -> BattleState:
	var battle_state := BattleState.new()
	_battle_sequence += 1
	battle_state.battle_id = "battle_%d" % _battle_sequence
	battle_state.source_room_id = source_room_id
	battle_state.phase = CombatEnums.BattlePhase.SETUP
	battle_state.register_combatant(_build_player_combatant(player))
	for index in monsters.size():
		var monster := monsters[index]
		if monster == null:
			continue
		battle_state.register_combatant(_build_monster_combatant(monster, index))
	battle_state.enemy_turn_order = _build_enemy_turn_order(battle_state)
	battle_state.append_event(&"battle_created", {
		"player_id": battle_state.get_player().combatant_id if battle_state.get_player() != null else "",
		"enemy_ids": _extract_ids(battle_state.get_enemies(true)),
	})
	start_next_turn(battle_state, battle_state.get_player().combatant_id)
	return battle_state


func start_next_turn(battle_state: BattleState, combatant_id: String) -> void:
	if battle_state == null or battle_state.is_finished:
		return
	var owner := battle_state.get_combatant(combatant_id)
	if owner == null or not owner.is_alive():
		return
	battle_state.phase = CombatEnums.BattlePhase.TURN_START
	battle_state.active_combatant_id = combatant_id
	battle_state.total_turns_started += 1
	var turn_state := TurnState.new(combatant_id, battle_state.current_round, battle_state.total_turns_started)
	turn_state.set_rolled_dice(_roll_dice_for_combatant(owner))
	battle_state.turn_state = turn_state
	battle_state.phase = CombatEnums.BattlePhase.DECISION
	battle_state.append_event(&"turn_started", {
		"combatant_id": combatant_id,
		"rolled_values": _extract_die_values(turn_state.dice_pool.rolled),
	})


func activate_player_ability(
	battle_state: BattleState,
	ability: AbilityDefinition,
	target_ids: PackedStringArray,
	selected_dice_ids: Array[String]
) -> Dictionary:
	if battle_state == null or battle_state.turn_state == null:
		return {"ok": false, "reason": "battle_not_ready"}
	var intent := BattleActionIntent.new(
		battle_state.active_combatant_id,
		ability,
		target_ids,
		selected_dice_ids
	)
	return resolve_intent(battle_state, battle_state.turn_state, intent)


func resolve_intent(battle_state: BattleState, turn_state: TurnState, intent: BattleActionIntent) -> Dictionary:
	if not can_resolve_intent(battle_state, turn_state, intent):
		return {"ok": false, "reason": "intent_invalid"}
	var source := battle_state.get_combatant(intent.source_id)
	var ability := intent.ability
	var selection := _build_selection_from_intent(turn_state, ability, intent.selected_dice_ids)
	if ability.cost != null and ability.cost.requires_dice() and selection.is_empty():
		return {"ok": false, "reason": "cost_not_paid"}

	battle_state.phase = CombatEnums.BattlePhase.RESOLUTION
	var spent_dice := turn_state.dice_pool.spend_selection(selection, ability.cost.dice_conditions if ability.cost != null else [])
	turn_state.mark_ability_used(ability.ability_id)
	battle_state.append_event(&"ability_activated", {
		"source_id": source.combatant_id,
		"ability_id": ability.ability_id,
		"target_ids": PackedStringArray(intent.target_ids),
		"spent_dice": _extract_die_values(spent_dice),
	})

	var resolved_targets := _resolve_targets_from_ids(battle_state, source, ability, intent.target_ids)
	for effect in ability.effects:
		if effect == null:
			continue
		_apply_effect(battle_state, source, resolved_targets, effect, spent_dice)
		if _evaluate_battle_end(battle_state):
			break

	if not battle_state.is_finished:
		battle_state.phase = CombatEnums.BattlePhase.DECISION
	return {"ok": true, "spent_dice": spent_dice, "battle_finished": battle_state.is_finished}


func can_resolve_intent(battle_state: BattleState, turn_state: TurnState, intent: BattleActionIntent) -> bool:
	if battle_state == null or turn_state == null or intent == null or intent.ability == null:
		return false
	if battle_state.is_finished:
		return false
	if intent.source_id != turn_state.turn_owner_id or intent.source_id != battle_state.active_combatant_id:
		return false
	var source := battle_state.get_combatant(intent.source_id)
	if source == null or not source.is_alive() or not source.supports_ability(intent.ability):
		return false
	if not _check_conditions(source, turn_state, intent.ability.use_conditions, intent.selected_dice_ids):
		return false
	if intent.ability.cost != null and intent.ability.cost.requires_dice():
		var selection := _build_selection_from_intent(turn_state, intent.ability, intent.selected_dice_ids)
		if selection.is_empty():
			return false
	var targets := _resolve_targets_from_ids(battle_state, source, intent.ability, intent.target_ids)
	if intent.ability.target_rule != null and intent.ability.target_rule.requires_target_selection():
		if targets.is_empty():
			return false
	return true


func end_turn(battle_state: BattleState, reason: CombatEnums.TurnEndReason = CombatEnums.TurnEndReason.MANUAL) -> void:
	if battle_state == null or battle_state.turn_state == null or battle_state.is_finished:
		return
	battle_state.phase = CombatEnums.BattlePhase.TURN_END
	battle_state.turn_state.end_reason = reason
	battle_state.append_event(&"turn_ended", {
		"combatant_id": battle_state.turn_state.turn_owner_id,
		"reason": reason,
		"remaining_dice": _extract_die_values(battle_state.turn_state.get_available_dice()),
	})
	advance_turn_order(battle_state)


func advance_turn_order(battle_state: BattleState) -> void:
	if battle_state == null or battle_state.is_finished:
		return
	if _evaluate_battle_end(battle_state):
		return

	var active := battle_state.get_combatant(battle_state.active_combatant_id)
	if active != null and active.side == CombatEnums.Side.PLAYER:
		battle_state.enemy_turn_order = _build_enemy_turn_order(battle_state)
		battle_state.enemy_turn_cursor = 0
		_start_next_alive_enemy_or_player(battle_state)
		return

	battle_state.enemy_turn_cursor += 1
	_start_next_alive_enemy_or_player(battle_state)


func run_current_monster_turn(battle_state: BattleState) -> void:
	if battle_state == null or battle_state.is_finished:
		return
	var monster := battle_state.get_combatant(battle_state.active_combatant_id)
	if monster == null or monster.side != CombatEnums.Side.ENEMY or battle_state.turn_state == null:
		return
	var intent := monster_ai.choose_action(battle_state, monster, battle_state.turn_state, self)
	if intent != null:
		resolve_intent(battle_state, battle_state.turn_state, intent)
	if not battle_state.is_finished:
		end_turn(battle_state, CombatEnums.TurnEndReason.AI_COMPLETED)


func run_monsters_until_player_turn(battle_state: BattleState) -> void:
	while battle_state != null and not battle_state.is_finished:
		var active := battle_state.get_combatant(battle_state.active_combatant_id)
		if active == null or active.side == CombatEnums.Side.PLAYER:
			return
		run_current_monster_turn(battle_state)


func build_auto_cost_selection(turn_state: TurnState, ability: AbilityDefinition) -> Dictionary:
	if turn_state == null or ability == null or ability.cost == null:
		return {}
	if not ability.cost.requires_dice():
		return {}
	return turn_state.dice_pool.auto_select_cost(ability.cost.dice_conditions)


func flatten_selection_ids(selection: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var keys := selection.keys()
	keys.sort()
	for key in keys:
		var dice: Array = selection[key]
		for die_value in dice:
			var die := die_value as TurnDie
			if die != null:
				ids.append(die.die_id)
	return ids


func resolve_default_targets(
	battle_state: BattleState,
	source: CombatantRuntime,
	ability: AbilityDefinition
) -> PackedStringArray:
	var resolved := PackedStringArray()
	if battle_state == null or source == null or ability == null:
		return resolved
	var target_rule := ability.target_rule
	if target_rule == null or not target_rule.requires_target_selection():
		if target_rule != null and target_rule.allow_self:
			resolved.append(source.combatant_id)
		return resolved
	if target_rule.allow_self and ability.target_rule.selection == AbilityTargetRule.Selection.NONE:
		resolved.append(source.combatant_id)
		return resolved
	if ability.target_rule.side == AbilityTargetRule.Side.SELF or (target_rule.allow_self and is_healing_ability(ability)):
		resolved.append(source.combatant_id)
		return resolved
	var opponents := battle_state.get_opponents(source)
	if target_rule.side == AbilityTargetRule.Side.ALLY:
		if source.is_alive():
			resolved.append(source.combatant_id)
		return resolved
	if target_rule.selection == AbilityTargetRule.Selection.ALL:
		for opponent in opponents:
			resolved.append(opponent.combatant_id)
		return resolved
	if not opponents.is_empty():
		resolved.append(opponents[0].combatant_id)
	return resolved


func is_healing_ability(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	for effect in ability.effects:
		if effect != null and effect.effect_type == &"healing":
			return true
	return false


func _build_player_combatant(player: Player) -> CombatantRuntime:
	var combatant := CombatantRuntime.new()
	combatant.side = CombatEnums.Side.PLAYER
	combatant.combatant_id = player.player_id if player != null and not player.player_id.is_empty() else "player"
	combatant.display_name = player.base_stat.display_name if player != null and player.base_stat != null else "Player"
	combatant.definition_ref = player.base_stat if player != null else null
	combatant.current_hp = player.current_hp if player != null else 0
	combatant.max_hp = player.base_stat.max_hp if player != null and player.base_stat != null else combatant.current_hp
	combatant.armor = player.current_armor if player != null else 0
	combatant.abilities = player.ability_loadout.duplicate() if player != null else []
	combatant.dice_loadout = player.dice_loadout.duplicate() if player != null else []
	combatant.fallback_dice_count = combatant.dice_loadout.size()
	combatant.spawn_index = 0
	combatant.tags = player.base_stat.tags if player != null and player.base_stat != null else PackedStringArray()
	return combatant


func _build_monster_combatant(monster: MonsterDefinition, spawn_index: int) -> CombatantRuntime:
	var combatant := CombatantRuntime.new()
	combatant.side = CombatEnums.Side.ENEMY
	combatant.combatant_id = "%s_%d" % [monster.monster_id, spawn_index]
	combatant.display_name = monster.display_name
	combatant.definition_ref = monster
	combatant.current_hp = monster.max_health
	combatant.max_hp = monster.max_health
	combatant.armor = 0
	combatant.abilities = monster.abilities.duplicate()
	combatant.fallback_dice_count = monster.dice_count
	combatant.spawn_index = spawn_index
	combatant.tags = monster.tags
	return combatant


func _build_enemy_turn_order(battle_state: BattleState) -> Array[String]:
	var enemies := battle_state.get_enemies()
	enemies.sort_custom(func(a: CombatantRuntime, b: CombatantRuntime) -> bool:
		if a.get_dice_count() == b.get_dice_count():
			return a.spawn_index < b.spawn_index
		return a.get_dice_count() > b.get_dice_count()
	)
	return _extract_ids(enemies)


func _start_next_alive_enemy_or_player(battle_state: BattleState) -> void:
	while battle_state.enemy_turn_cursor < battle_state.enemy_turn_order.size():
		var enemy_id: String = battle_state.enemy_turn_order[battle_state.enemy_turn_cursor]
		var enemy := battle_state.get_combatant(enemy_id)
		if enemy != null and enemy.is_alive():
			start_next_turn(battle_state, enemy_id)
			return
		battle_state.enemy_turn_cursor += 1
	battle_state.current_round += 1
	start_next_turn(battle_state, battle_state.get_player().combatant_id)


func _roll_dice_for_combatant(combatant: CombatantRuntime) -> Array[TurnDie]:
	var rolled: Array[TurnDie] = []
	for index in combatant.get_dice_count():
		var dice_definition: DiceDefinition = null
		if index < combatant.dice_loadout.size():
			dice_definition = combatant.dice_loadout[index]
		var die := _roll_single_die(combatant, index, dice_definition)
		rolled.append(die)
	return rolled


func _roll_single_die(combatant: CombatantRuntime, source_index: int, dice_definition: DiceDefinition) -> TurnDie:
	var face_count := 6
	if dice_definition != null and dice_definition.get_face_count() > 0:
		face_count = dice_definition.get_face_count()
	var rolled_face_index := randi_range(0, maxi(face_count - 1, 0))
	var rolled_value := rolled_face_index + 1
	var face_id := ""
	var tags := PackedStringArray()
	if dice_definition != null:
		tags.append(dice_definition.dice_name)
		var face = dice_definition.get_face(rolled_face_index)
		if face != null:
			face_id = str(rolled_face_index)
			rolled_value = int(face.text_value) if String(face.text_value).is_valid_int() else rolled_value
	return TurnDie.new(
		"%s_die_%d_%d" % [combatant.combatant_id, battle_state_safe_turn_index(source_index), source_index],
		combatant.combatant_id,
		source_index,
		rolled_value,
		tags,
		face_id,
		{}
	)


func battle_state_safe_turn_index(source_index: int) -> int:
	return Time.get_ticks_usec() + source_index


func _check_conditions(
	source: CombatantRuntime,
	turn_state: TurnState,
	conditions: Array[AbilityCondition],
	selected_dice_ids: Array[String]
) -> bool:
	for condition in conditions:
		if condition == null:
			return false
		var result := _evaluate_condition(source, turn_state, condition, selected_dice_ids)
		if condition.inverted:
			result = not result
		if not result:
			return false
	return true


func _evaluate_condition(
	source: CombatantRuntime,
	turn_state: TurnState,
	condition: AbilityCondition,
	selected_dice_ids: Array[String]
) -> bool:
	match String(condition.predicate):
		"selected_die_top_face_parity":
			if selected_dice_ids.is_empty():
				return false
			var die := turn_state.dice_pool.get_die_by_id(selected_dice_ids[0])
			if die == null:
				return false
			var parity := String(condition.parameters.get("parity", "even"))
			return die.value % 2 == 0 if parity == "even" else die.value % 2 != 0
		"has_tag":
			var tag := String(condition.parameters.get("tag", ""))
			return source.tags.has(tag)
		_:
			return true


func _build_selection_from_intent(turn_state: TurnState, ability: AbilityDefinition, selected_dice_ids: Array[String]) -> Dictionary:
	if turn_state == null or ability == null or ability.cost == null or not ability.cost.requires_dice():
		return {}
	return turn_state.dice_pool.build_cost_selection(ability.cost.dice_conditions, selected_dice_ids)


func _resolve_targets_from_ids(
	battle_state: BattleState,
	source: CombatantRuntime,
	ability: AbilityDefinition,
	target_ids: PackedStringArray
) -> Array[CombatantRuntime]:
	var resolved: Array[CombatantRuntime] = []
	var rule := ability.target_rule
	if rule == null or not rule.requires_target_selection():
		if rule != null and rule.allow_self:
			resolved.append(source)
		return resolved
	if target_ids.is_empty():
		for target_id in resolve_default_targets(battle_state, source, ability):
			var fallback_target := battle_state.get_combatant(target_id)
			if fallback_target != null and fallback_target.is_alive():
				resolved.append(fallback_target)
		return resolved
	for target_id in target_ids:
		var combatant := battle_state.get_combatant(target_id)
		if combatant == null:
			continue
		if not rule.can_target_dead and not combatant.is_alive():
			continue
		if combatant.combatant_id == source.combatant_id and not rule.allow_self and rule.side != AbilityTargetRule.Side.SELF:
			continue
		resolved.append(combatant)
	if rule.selection == AbilityTargetRule.Selection.ALL:
		return resolved
	if resolved.size() > rule.max_targets and rule.max_targets > 0:
		resolved.resize(rule.max_targets)
	return resolved


func _apply_effect(
	battle_state: BattleState,
	source: CombatantRuntime,
	targets: Array[CombatantRuntime],
	effect: AbilityEffectDefinition,
	spent_dice: Array[TurnDie]
) -> void:
	var repeat_count := maxi(effect.repeat_count, 1)
	for _repeat in repeat_count:
		for target in targets:
			if target == null:
				continue
			match effect.effect_type:
				&"damage":
					var dealt := target.take_damage(_resolve_effect_magnitude(effect, spent_dice))
					battle_state.append_event(&"damage_applied", {
						"source_id": source.combatant_id,
						"target_id": target.combatant_id,
						"amount": dealt,
						"remaining_hp": target.current_hp,
					})
				&"healing":
					var restored := target.heal(_resolve_effect_magnitude(effect, spent_dice))
					battle_state.append_event(&"healing_applied", {
						"source_id": source.combatant_id,
						"target_id": target.combatant_id,
						"amount": restored,
						"current_hp": target.current_hp,
					})
				&"armor":
					target.armor += _resolve_effect_magnitude(effect, spent_dice)
					battle_state.append_event(&"armor_gained", {
						"source_id": source.combatant_id,
						"target_id": target.combatant_id,
						"armor": target.armor,
					})
				_:
					battle_state.append_event(&"effect_skipped", {
						"effect_type": effect.effect_type,
						"target_id": target.combatant_id,
					})
			if not target.is_alive():
				battle_state.append_event(&"combatant_died", {
					"combatant_id": target.combatant_id,
				})
			if _evaluate_battle_end(battle_state):
				return


func _resolve_effect_magnitude(effect: AbilityEffectDefinition, spent_dice: Array[TurnDie]) -> int:
	var magnitude := effect.magnitude
	if effect.scale_with_power != 0.0 and not spent_dice.is_empty():
		var total_power := 0
		for die in spent_dice:
			total_power += die.value
		magnitude += int(round(total_power * effect.scale_with_power))
	return maxi(magnitude, 0)


func _evaluate_battle_end(battle_state: BattleState) -> bool:
	if battle_state == null or battle_state.is_finished:
		return battle_state != null and battle_state.is_finished
	var player := battle_state.get_player()
	if player == null or not player.is_alive():
		_finish_battle(battle_state, CombatEnums.BattleOutcome.PLAYER_DEFEAT, &"player_dead")
		return true
	if battle_state.get_enemies().is_empty():
		_finish_battle(battle_state, CombatEnums.BattleOutcome.PLAYER_VICTORY, &"all_monsters_defeated")
		return true
	return false


func _finish_battle(battle_state: BattleState, outcome: CombatEnums.BattleOutcome, reason: StringName) -> void:
	battle_state.is_finished = true
	battle_state.phase = CombatEnums.BattlePhase.FINISHED
	battle_state.result = BattleResult.new()
	battle_state.result.outcome = outcome
	battle_state.result.reason = reason
	for combatant in battle_state.combatants:
		if combatant == null:
			continue
		if combatant.is_alive():
			battle_state.result.surviving_ids.append(combatant.combatant_id)
		else:
			battle_state.result.defeated_ids.append(combatant.combatant_id)
	battle_state.append_event(&"battle_finished", {
		"outcome": outcome,
		"reason": reason,
	})


func _extract_ids(combatants: Array[CombatantRuntime]) -> Array[String]:
	var ids: Array[String] = []
	for combatant in combatants:
		if combatant != null:
			ids.append(combatant.combatant_id)
	return ids


func _extract_die_values(dice: Array[TurnDie]) -> Array[int]:
	var values: Array[int] = []
	for die in dice:
		if die != null:
			values.append(die.value)
	return values
