extends Entity
class_name MonsterEntity

var ai_profile: MonsterAIDefinition
var ai_blackboard_snapshot: Dictionary = {}


func _init() -> void:
	super()
	entity_type = EntityType.MONSTER
	faction = Faction.ENEMY


func has_valid_ai() -> bool:
	return ai_profile != null and ai_profile.is_valid_definition()
