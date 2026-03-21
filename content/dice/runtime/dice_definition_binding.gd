extends RefCounted
class_name DiceDefinitionBinding

signal definition_changed

var _bound_definition: DiceDefinition


func bind(definition: DiceDefinition) -> void:
	if _bound_definition == definition:
		return

	unbind()
	_bound_definition = definition

	if _bound_definition != null and not _bound_definition.changed.is_connected(_on_definition_changed):
		_bound_definition.changed.connect(_on_definition_changed)

	emit_signal("definition_changed")


func unbind() -> void:
	if _bound_definition != null and _bound_definition.changed.is_connected(_on_definition_changed):
		_bound_definition.changed.disconnect(_on_definition_changed)
	_bound_definition = null


func get_configuration_warnings(definition: DiceDefinition) -> PackedStringArray:
	var warnings := PackedStringArray()
	if definition == null:
		warnings.append("Dice requires a DiceDefinition resource.")
	elif definition.faces.size() != DiceDefinition.FACE_COUNT:
		warnings.append("DiceDefinition should define exactly 6 faces for a standard cube.")
	return warnings


func _on_definition_changed() -> void:
	emit_signal("definition_changed")
