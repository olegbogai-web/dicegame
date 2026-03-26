extends RefCounted
class_name HeroIconMovementController

const HERO_STRAIGHT := preload("res://assets/global_map/hero_straight.png")
const HERO_RIGHT := preload("res://assets/global_map/hero_right.png")
const HERO_BACK := preload("res://assets/global_map/hero_back.png")

const MIN_AXIS_EPSILON := 0.03

var _hero_icon: MeshInstance3D
var _hero_material: StandardMaterial3D


func setup(hero_icon: MeshInstance3D) -> void:
	_hero_icon = hero_icon
	if _hero_icon == null:
		return
	_hero_material = _hero_icon.material_override as StandardMaterial3D


func apply_idle_sprite() -> void:
	_apply_sprite(HERO_STRAIGHT, false)


func update_sprite_for_motion(from_position: Vector3, to_position: Vector3) -> void:
	var delta := to_position - from_position
	if absf(delta.z) >= absf(delta.x) and absf(delta.z) > MIN_AXIS_EPSILON:
		if delta.z > 0.0:
			_apply_sprite(HERO_STRAIGHT, false)
		else:
			_apply_sprite(HERO_BACK, false)
		return
	if absf(delta.x) > MIN_AXIS_EPSILON:
		_apply_sprite(HERO_RIGHT, delta.x < 0.0)
		return
	apply_idle_sprite()


func _apply_sprite(texture: Texture2D, mirror_x: bool) -> void:
	if _hero_material == null:
		return
	_hero_material.albedo_texture = texture
	if _hero_icon == null:
		return
	var icon_scale := _hero_icon.scale
	icon_scale.x = absf(icon_scale.x) * (-1.0 if mirror_x else 1.0)
	_hero_icon.scale = icon_scale
