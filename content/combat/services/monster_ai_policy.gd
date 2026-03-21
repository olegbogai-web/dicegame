extends RefCounted
class_name MonsterAiPolicy

const BattleActionIntent = preload("res://content/combat/runtime/battle_action_intent.gd")
const BattleState = preload("res://content/combat/runtime/battle_state.gd")
const CombatantRuntime = preload("res://content/combat/runtime/combatant_runtime.gd")
const TurnState = preload("res://content/combat/runtime/turn_state.gd")


func choose_action(
	battle_state: BattleState,
	monster: CombatantRuntime,
	turn_state: TurnState,
	combat_service: RefCounted
) -> BattleActionIntent:
	if battle_state == null or monster == null or turn_state == null or combat_service == null:
		return null

	var chosen_heal: BattleActionIntent = null
	for ability in monster.abilities:
		if ability == null:
			continue
		var selection: Dictionary = combat_service.build_auto_cost_selection(turn_state, ability)
		if selection.is_empty() and ability.cost != null and ability.cost.requires_dice():
			continue
		var selected_ids := combat_service.flatten_selection_ids(selection)
		var targets := combat_service.resolve_default_targets(battle_state, monster, ability)
		if targets.is_empty() and ability.target_rule != null and ability.target_rule.requires_target_selection():
			continue
		var intent := BattleActionIntent.new(monster.combatant_id, ability, targets, selected_ids)
		if combat_service.can_resolve_intent(battle_state, turn_state, intent):
			if combat_service.is_healing_ability(ability) and monster.current_hp < monster.max_hp:
				return intent
			if chosen_heal == null:
				chosen_heal = intent
	if chosen_heal != null:
		return chosen_heal
	return null
