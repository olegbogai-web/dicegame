extends RefCounted
class_name TurnDie

var die_id := ""
var owner_id := ""
var source_index := 0
var value := 1
var tags: PackedStringArray = PackedStringArray()
var face_id := ""
var metadata: Dictionary = {}


func _init(
	next_die_id: String = "",
	next_owner_id: String = "",
	next_source_index: int = 0,
	next_value: int = 1,
	next_tags: PackedStringArray = PackedStringArray(),
	next_face_id: String = "",
	next_metadata: Dictionary = {}
) -> void:
	die_id = next_die_id
	owner_id = next_owner_id
	source_index = maxi(next_source_index, 0)
	value = maxi(next_value, 1)
	tags = PackedStringArray(next_tags)
	face_id = next_face_id
	metadata = next_metadata.duplicate(true)
