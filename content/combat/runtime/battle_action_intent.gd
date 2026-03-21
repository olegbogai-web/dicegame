extends RefCounted
class_name BattleActionIntent

var source_id := ""
var ability: AbilityDefinition
var target_ids: PackedStringArray = PackedStringArray()
var selected_dice_ids: Array[String] = []
var metadata: Dictionary = {}


func _init(
	next_source_id: String = "",
	next_ability: AbilityDefinition = null,
	next_target_ids: PackedStringArray = PackedStringArray(),
	next_selected_dice_ids: Array[String] = [],
	next_metadata: Dictionary = {}
) -> void:
	source_id = next_source_id
	ability = next_ability
	target_ids = PackedStringArray(next_target_ids)
	selected_dice_ids = next_selected_dice_ids.duplicate()
	metadata = next_metadata.duplicate(true)
