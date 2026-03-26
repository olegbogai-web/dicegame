extends RefCounted
class_name HeroIconMovementController

const HeroIconSpriteResolver = preload("res://content/global_map/presentation/hero_icon_sprite_resolver.gd")

const MOVE_SPEED_UNITS_PER_SECOND := 11.0

var _sprite_resolver := HeroIconSpriteResolver.new()


func move_hero_along_path(hero_icon: MeshInstance3D, waypoints: Array[Vector3], hero_straight: Texture2D, hero_back: Texture2D, hero_right: Texture2D) -> void:
	if hero_icon == null:
		return
	if waypoints.is_empty():
		return

	for waypoint in waypoints:
		var offset := waypoint - hero_icon.global_position
		if offset.length() <= 0.001:
			continue
		_sprite_resolver.apply_sprite_for_direction(hero_icon, offset.normalized(), hero_straight, hero_back, hero_right)
		var travel_time := max(offset.length() / MOVE_SPEED_UNITS_PER_SECOND, 0.05)
		var tween := hero_icon.create_tween()
		tween.tween_property(hero_icon, "global_position", waypoint, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
