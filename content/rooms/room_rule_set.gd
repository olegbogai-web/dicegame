@tool
extends Resource
class_name RoomRuleSet

@export var rule_refs: PackedStringArray = PackedStringArray()
@export var rule_priorities: Dictionary = {}
@export var rule_scopes: Dictionary = {}


func has_rule(rule_ref: StringName) -> bool:
	return rule_refs.has(String(rule_ref))


func get_priority(rule_ref: StringName) -> int:
	return int(rule_priorities.get(String(rule_ref), 0))


func get_scope(rule_ref: StringName) -> StringName:
	return StringName(rule_scopes.get(String(rule_ref), &"active"))
