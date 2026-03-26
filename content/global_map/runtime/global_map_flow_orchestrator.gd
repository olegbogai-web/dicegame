extends RefCounted
class_name GlobalMapFlowOrchestrator

const GlobalMapPathPresenter = preload("res://content/global_map/presentation/global_map_path_presenter.gd")
const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapTransitionService = preload("res://content/global_map/runtime/global_map_transition_service.gd")

var _path_presenter := GlobalMapPathPresenter.new()
var _movement_controller := HeroIconMovementController.new()
var _transition_service := GlobalMapTransitionService.new()


func try_pick_event(camera_map: Camera3D, event_position: Vector2, event_body: CollisionObject3D) -> bool:
	if camera_map == null or event_body == null:
		return false
	var space_state := camera_map.get_world_3d().direct_space_state
	var ray_origin := camera_map.project_ray_origin(event_position)
	var ray_direction := camera_map.project_ray_normal(event_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 250.0)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return hit.get("collider") == event_body


func run_event_transition(root: Node3D, hero_icon: MeshInstance3D, event_icon: MeshInstance3D, fade_rect: ColorRect, hero_straight: Texture2D, hero_back: Texture2D, hero_right: Texture2D, target_scene_path: String) -> void:
	var waypoints := _path_presenter.collect_path_waypoints(root, hero_icon, event_icon)
	await _movement_controller.move_hero_along_path(hero_icon, waypoints, hero_straight, hero_back, hero_right)
	await _transition_service.enter_room(root.get_tree(), hero_icon, event_icon, fade_rect, hero_straight, target_scene_path)
