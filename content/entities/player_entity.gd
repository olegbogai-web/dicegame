extends Entity
class_name PlayerEntity

var run_metadata: Dictionary = {}
var progression_metadata: Dictionary = {}


func _init() -> void:
	super()
	entity_type = EntityType.PLAYER
	faction = Faction.PLAYER
