extends RefCounted
class_name CombatantRuntimeState

const StatusContainer = preload("res://content/statuses/runtime/status_container.gd")

var combatant_id: StringName = &""
var side: StringName = &""
var is_alive := true
var statuses: StatusContainer


func _init(next_combatant_id: StringName = &"", next_side: StringName = &"") -> void:
	combatant_id = next_combatant_id
	side = next_side
	is_alive = true
	statuses = StatusContainer.new(combatant_id)
