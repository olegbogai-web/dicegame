extends RefCounted
class_name BattleTargetingService

const BattleEnums = preload("res://content/combat/resources/battle_enums.gd")


func get_valid_targets(state: BattleState, source: BattleCombatant, rule: AbilityTargetRule) -> Array[BattleCombatant]:
	var targets: Array[BattleCombatant] = []
	if state == null or source == null or rule == null:
		return targets

	if rule.selection == AbilityTargetRule.Selection.NONE:
		if rule.allow_self or rule.side == AbilityTargetRule.Side.SELF:
			targets.append(source)
		return targets

	for combatant in state.combatants:
		if not rule.can_target_dead and not combatant.is_alive():
			continue
		if not _matches_side(source, combatant, rule):
			continue
		targets.append(combatant)

	return targets


func resolve_ai_targets(state: BattleState, source: BattleCombatant, rule: AbilityTargetRule) -> Array[BattleCombatant]:
	var valid_targets := get_valid_targets(state, source, rule)
	if valid_targets.is_empty():
		return []
	if rule.selection == AbilityTargetRule.Selection.ALL:
		return valid_targets
	return [valid_targets[0]]


func _matches_side(source: BattleCombatant, target: BattleCombatant, rule: AbilityTargetRule) -> bool:
	match rule.side:
		AbilityTargetRule.Side.SELF:
			return source.combatant_id == target.combatant_id
		AbilityTargetRule.Side.ALLY:
			return source.side == target.side and (rule.allow_self or source.combatant_id != target.combatant_id)
		AbilityTargetRule.Side.ENEMY:
			return source.side != target.side
		AbilityTargetRule.Side.ANY:
			return rule.allow_self or source.combatant_id != target.combatant_id or source.combatant_id == target.combatant_id
		_:
			return false
