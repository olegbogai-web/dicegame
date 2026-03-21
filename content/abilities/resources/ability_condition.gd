@tool
extends Resource
class_name AbilityCondition

# Generic gate that can be interpreted by validation/runtime systems.
# Conditions cover actor state, target state, battle phase and event-driven checks.

enum Subject {
	SOURCE,
	TARGET,
	BATTLE,
	RUN,
}

@export var condition_id := ""
@export var subject: Subject = Subject.SOURCE
@export var predicate := &"has_tag"
@export var inverted := false
@export var parameters: Dictionary = {}


func is_valid_definition() -> bool:
	return not condition_id.is_empty() and predicate != &""
