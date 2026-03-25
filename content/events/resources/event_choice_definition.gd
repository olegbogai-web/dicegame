@tool
extends Resource
class_name EventChoiceDefinition

@export_category("Identity")
@export var choice_id := ""
@export_multiline var choice_text := ""

@export_category("Dice")
@export_range(0, 6, 1) var positive_faces := 0
@export_range(0, 6, 1) var neutral_faces := 0
@export_range(0, 6, 1) var negative_faces := 0

@export_category("Outcomes")
@export var positive_outcome: EventOutcomeDefinition
@export var neutral_outcome: EventOutcomeDefinition
@export var negative_outcome: EventOutcomeDefinition


func is_valid_definition() -> bool:
	if choice_id.is_empty() or choice_text.is_empty():
		return false
	if positive_outcome == null or neutral_outcome == null or negative_outcome == null:
		return false
	if not positive_outcome.is_valid_definition() or not neutral_outcome.is_valid_definition() or not negative_outcome.is_valid_definition():
		return false
	return positive_faces >= 0 and neutral_faces >= 0 and negative_faces >= 0 and get_total_faces() > 0


func get_total_faces() -> int:
	return positive_faces + neutral_faces + negative_faces


func build_face_pool() -> Array[EventOutcomeDefinition.OutcomeKind]:
	var pool: Array[EventOutcomeDefinition.OutcomeKind] = []
	for _index in positive_faces:
		pool.append(EventOutcomeDefinition.OutcomeKind.POSITIVE)
	for _index in neutral_faces:
		pool.append(EventOutcomeDefinition.OutcomeKind.NEUTRAL)
	for _index in negative_faces:
		pool.append(EventOutcomeDefinition.OutcomeKind.NEGATIVE)
	return pool


func get_outcome_for_kind(kind: EventOutcomeDefinition.OutcomeKind) -> EventOutcomeDefinition:
	match kind:
		EventOutcomeDefinition.OutcomeKind.POSITIVE:
			return positive_outcome
		EventOutcomeDefinition.OutcomeKind.NEGATIVE:
			return negative_outcome
		_:
			return neutral_outcome
