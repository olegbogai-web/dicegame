extends RefCounted
class_name GlobalMapTransitionService

const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")

var _fade_presenter := GlobalMapFadeTransitionPresenter.new()


func enter_room(scene_tree: SceneTree, hero_icon: MeshInstance3D, event_icon: MeshInstance3D, fade_rect: ColorRect, hero_straight: Texture2D, target_scene_path: String) -> void:
	if hero_icon != null:
		var hero_material := hero_icon.material_override as StandardMaterial3D
		if hero_material != null:
			hero_material.albedo_texture = hero_straight
		hero_icon.scale.x = abs(hero_icon.scale.x)

	if event_icon != null:
		event_icon.visible = false

	await _fade_presenter.fade_to_black(fade_rect)
	if scene_tree == null:
		return
	if target_scene_path.is_empty():
		return
	scene_tree.change_scene_to_file(target_scene_path)
