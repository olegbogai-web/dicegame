extends RefCounted
class_name GlobalMapTransitionService

var _next_scene_path := ""


func setup(next_scene_path: String) -> void:
	_next_scene_path = next_scene_path


func open_selected_room(scene_tree: SceneTree) -> void:
	if scene_tree == null:
		return
	if _next_scene_path.is_empty():
		push_warning("GlobalMapTransitionService: next scene path is empty.")
		return
	var result := scene_tree.change_scene_to_file(_next_scene_path)
	if result != OK:
		push_warning("GlobalMapTransitionService: failed to open scene %s" % _next_scene_path)
