extends RefCounted
class_name BattleResult

const CombatEnums = preload("res://content/combat/resources/combat_enums.gd")

var outcome: CombatEnums.BattleOutcome = CombatEnums.BattleOutcome.NONE
var reason: StringName = &""
var surviving_ids: PackedStringArray = PackedStringArray()
var defeated_ids: PackedStringArray = PackedStringArray()
var payload: Dictionary = {}


func is_finished() -> bool:
	return outcome != CombatEnums.BattleOutcome.NONE
