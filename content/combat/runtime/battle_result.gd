extends RefCounted
class_name BattleResult

const BattleEnums = preload("res://content/combat/resources/battle_enums.gd")

var result_type: BattleEnums.ResultType = BattleEnums.ResultType.NONE
var reason := &""
var surviving_ids: PackedStringArray = PackedStringArray()
var defeated_ids: PackedStringArray = PackedStringArray()
