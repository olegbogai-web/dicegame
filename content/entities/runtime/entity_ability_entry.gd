extends RefCounted
class_name EntityAbilityEntry

var definition: AbilityDefinition
var current_cooldown := 0
var charges_left := 0
var is_exhausted := false
var metadata: Dictionary = {}


func configure(ability_definition: AbilityDefinition, extra_metadata: Dictionary = {}) -> EntityAbilityEntry:
	definition = ability_definition
	metadata = extra_metadata.duplicate(true)
	if definition != null:
		charges_left = definition.charges
		current_cooldown = definition.cooldown_turns if definition.starts_on_cooldown else 0
	return self


func get_ability_id() -> StringName:
	if definition == null:
		return StringName()
	return StringName(definition.ability_id)
