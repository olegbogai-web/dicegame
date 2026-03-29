extends RefCounted
class_name ArtifactInstance

var definition: ArtifactDefinition
var runtime_counters: Dictionary = {}


func _init(next_definition: ArtifactDefinition = null) -> void:
	definition = next_definition


func is_valid() -> bool:
	return definition != null and definition.is_valid_definition()
