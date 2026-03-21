extends RefCounted
class_name RoomState

var status: RoomEnums.RoomStatus = RoomEnums.RoomStatus.CREATED
var visited := false
var completed_successfully := false
var abandoned := false
var completion_reason: StringName
var runtime_flags: Dictionary = {}
var active_modifier_refs: PackedStringArray = PackedStringArray()
var resolution_payload: Dictionary = {}


func is_terminal() -> bool:
	return status in [
		RoomEnums.RoomStatus.COMPLETED,
		RoomEnums.RoomStatus.FAILED,
		RoomEnums.RoomStatus.ABANDONED,
	]


func get_status_tag() -> String:
	return RoomEnums.get_room_status_tag(status)
