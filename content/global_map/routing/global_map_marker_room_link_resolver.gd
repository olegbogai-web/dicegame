extends RefCounted
class_name GlobalMapMarkerRoomLinkResolver

const TEST_EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"
const TEST_BATTLE_ROOM_SCENE_PATH := "res://scenes/new_battle_table.tscn"
const EVENT_ICON := preload("res://assets/global_map/question_mark.png")
const BATTLE_ICON := preload("res://assets/global_map/swords.png")


func resolve_marker_for_face(face: DiceFaceDefinition) -> Dictionary:
	if face == null:
		return _build_event_marker_data()
	var normalized_tag := face.text_value.strip_edges().to_lower()
	if normalized_tag == "swords":
		return _build_battle_marker_data()
	if normalized_tag == "question_mark":
		return _build_event_marker_data()
	return _build_event_marker_data()


func _build_event_marker_data() -> Dictionary:
	return {
		"scene_path": TEST_EVENT_ROOM_SCENE_PATH,
		"icon": EVENT_ICON,
		"type": "question_mark",
	}


func _build_battle_marker_data() -> Dictionary:
	return {
		"scene_path": TEST_BATTLE_ROOM_SCENE_PATH,
		"icon": BATTLE_ICON,
		"type": "swords",
	}
