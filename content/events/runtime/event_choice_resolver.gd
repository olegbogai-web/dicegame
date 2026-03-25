extends RefCounted
class_name EventChoiceResolver


static func resolve_outcome(choice: EventChoiceDefinition, color_tag: StringName, rng: RandomNumberGenerator) -> EventOutcomeDefinition:
	if choice == null:
		return null
	var pool := choice.get_outcomes_for_color(color_tag)
	if pool.is_empty():
		return null
	if rng == null:
		return pool[0]
	return pool[rng.randi_range(0, pool.size() - 1)]
