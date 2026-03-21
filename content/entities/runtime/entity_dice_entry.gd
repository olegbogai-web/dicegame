extends RefCounted
class_name EntityDiceEntry

var definition: DiceDefinition
var count := 1
var is_enabled := true
var tags: PackedStringArray = PackedStringArray()
var metadata: Dictionary = {}


func configure(
	dice_definition: DiceDefinition,
	dice_count: int = 1,
	dice_tags: PackedStringArray = PackedStringArray(),
	extra_metadata: Dictionary = {}
) -> EntityDiceEntry:
	definition = dice_definition
	count = max(dice_count, 0)
	tags = PackedStringArray(dice_tags)
	metadata = extra_metadata.duplicate(true)
	return self
