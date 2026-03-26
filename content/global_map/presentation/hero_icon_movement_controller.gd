extends RefCounted
class_name HeroIconMovementController

const HERO_STRAIGHT_TEXTURE := preload("res://assets/global_map/hero_straight.png")
const HERO_RIGHT_TEXTURE := preload("res://assets/global_map/hero_right.png")
const HERO_BACK_TEXTURE := preload("res://assets/global_map/hero_back.png")

const FORWARD_EPSILON := 0.02
const HERO_HEIGHT_OFFSET := 0.05

var _hero_icon: MeshInstance3D
var _base_scale: Vector3
var _material: StandardMaterial3D


func configure(hero_icon: MeshInstance3D) -> void:
	_hero_icon = hero_icon
	if _hero_icon == null:
		return
	_base_scale = _hero_icon.scale
	var source_material := _hero_icon.material_override as StandardMaterial3D
	if source_material != null:
		_material = source_material.duplicate() as StandardMaterial3D
		_hero_icon.material_override = _material
	_set_straight_sprite()


func update_direction(from_point: Vector3, to_point: Vector3) -> void:
	var direction := to_point - from_point
	if absf(direction.z) > absf(direction.x):
		if direction.z > FORWARD_EPSILON:
			_set_straight_sprite()
			_set_flip(false)
			return
		_set_back_sprite()
		_set_flip(false)
		return

	_set_right_sprite()
	if direction.x >= 0.0:
		_set_flip(false)
		return
	_set_flip(true)


func snap_to_idle() -> void:
	_set_straight_sprite()
	_set_flip(false)


func set_world_position(world_position: Vector3) -> void:
	if _hero_icon == null:
		return
	_hero_icon.global_position = world_position + Vector3(0.0, HERO_HEIGHT_OFFSET, 0.0)


func get_world_position() -> Vector3:
	if _hero_icon == null:
		return Vector3.ZERO
	return _hero_icon.global_position


func _set_straight_sprite() -> void:
	if _material == null:
		return
	_material.albedo_texture = HERO_STRAIGHT_TEXTURE


func _set_right_sprite() -> void:
	if _material == null:
		return
	_material.albedo_texture = HERO_RIGHT_TEXTURE


func _set_back_sprite() -> void:
	if _material == null:
		return
	_material.albedo_texture = HERO_BACK_TEXTURE


func _set_flip(is_flipped: bool) -> void:
	if _hero_icon == null:
		return
	var target_scale := _base_scale
	target_scale.x = -absf(_base_scale.x) if is_flipped else absf(_base_scale.x)
	_hero_icon.scale = target_scale
