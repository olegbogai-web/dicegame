extends RefCounted
class_name GlobalMapTransitionService


func open_event_room(scene_tree: SceneTree, scene_path: String) -> void:
	if scene_tree == null:
		return
	var result := scene_tree.change_scene_to_file(scene_path)
	if result != OK:
		push_warning("Failed to open scene: %s" % scene_path)
