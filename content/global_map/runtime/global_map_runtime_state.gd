extends RefCounted
class_name GlobalMapRuntimeState

var is_transition_in_progress := false
var has_event_been_resolved := false
var current_position := Vector3.ZERO


func begin_transition() -> void:
	is_transition_in_progress = true


func complete_transition() -> void:
	has_event_been_resolved = true
	is_transition_in_progress = false
