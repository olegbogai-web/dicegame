extends RefCounted
class_name HeroIconMovementController

const HERO_RIGHT := preload("res://assets/global_map/hero_right.png")
const HERO_STRAIGHT := preload("res://assets/global_map/hero_straight.png")
const HERO_BACK := preload("res://assets/global_map/hero_back.png")

const MIN_DIRECTION_THRESHOLD := 0.0005


func move_hero_along_path(hero_icon: MeshInstance3D, waypoints: Array[Vector3], speed: float) -> void:
	if hero_icon == null or waypoints.is_empty():
		return

	for waypoint in waypoints:
		await _move_to_waypoint(hero_icon, waypoint, speed)

	set_idle_straight(hero_icon)


func _move_to_waypoint(hero_icon: MeshInstance3D, waypoint: Vector3, speed: float) -> void:
	var step_speed := maxf(speed, 0.001)
	while hero_icon.global_position.distance_to(waypoint) > 0.03:
		var current := hero_icon.global_position
		var direction := (waypoint - current).normalized()
		_update_sprite_for_direction(hero_icon, direction)
		hero_icon.global_position = current.move_toward(waypoint, step_speed * hero_icon.get_process_delta_time())
		await hero_icon.get_tree().process_frame
	hero_icon.global_position = waypoint


func _update_sprite_for_direction(hero_icon: MeshInstance3D, direction: Vector3) -> void:
	if direction.length_squared() <= MIN_DIRECTION_THRESHOLD:
		set_idle_straight(hero_icon)
		return

	if absf(direction.x) > absf(direction.z):
		_set_right_sprite(hero_icon, direction.x < 0.0)
		return

	if direction.z >= 0.0:
		set_idle_straight(hero_icon)
		return

	_set_back_sprite(hero_icon)


func set_idle_straight(hero_icon: MeshInstance3D) -> void:
	_apply_texture(hero_icon, HERO_STRAIGHT)
	hero_icon.scale.x = absf(hero_icon.scale.x)


func _set_back_sprite(hero_icon: MeshInstance3D) -> void:
	_apply_texture(hero_icon, HERO_BACK)
	hero_icon.scale.x = absf(hero_icon.scale.x)


func _set_right_sprite(hero_icon: MeshInstance3D, mirror: bool) -> void:
	_apply_texture(hero_icon, HERO_RIGHT)
	hero_icon.scale.x = absf(hero_icon.scale.x) * (-1.0 if mirror else 1.0)


func _apply_texture(hero_icon: MeshInstance3D, texture: Texture2D) -> void:
	var material := hero_icon.material_override as StandardMaterial3D
	if material == null:
		return
	material.albedo_texture = texture
