extends RefCounted
class_name HeroIconSpriteResolver


func apply_sprite_for_direction(hero_icon: MeshInstance3D, move_direction: Vector3, hero_straight: Texture2D, hero_back: Texture2D, hero_right: Texture2D) -> void:
	if hero_icon == null:
		return

	var material := hero_icon.material_override as StandardMaterial3D
	if material == null:
		return

	if abs(move_direction.z) >= abs(move_direction.x):
		if move_direction.z < 0.0:
			material.albedo_texture = hero_back
			hero_icon.scale.x = abs(hero_icon.scale.x)
			return
		material.albedo_texture = hero_straight
		hero_icon.scale.x = abs(hero_icon.scale.x)
		return

	material.albedo_texture = hero_right
	hero_icon.scale.x = abs(hero_icon.scale.x)
	if move_direction.x < 0.0:
		hero_icon.scale.x *= -1.0
