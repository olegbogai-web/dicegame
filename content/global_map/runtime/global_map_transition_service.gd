extends RefCounted
class_name GlobalMapTransitionService

const EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"


func open_event_room(tree: SceneTree) -> void:
	if tree == null:
		return
	var result := tree.change_scene_to_file(EVENT_ROOM_SCENE_PATH)
	if result != OK:
		push_warning("Failed to open event room scene: %s" % EVENT_ROOM_SCENE_PATH)
