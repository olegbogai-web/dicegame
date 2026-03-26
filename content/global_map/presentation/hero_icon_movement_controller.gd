extends RefCounted
class_name HeroIconMovementController

const FORWARD_TEXTURE := preload("res://assets/global_map/hero_straight.png")
const RIGHT_TEXTURE := preload("res://assets/global_map/hero_right.png")
const BACK_TEXTURE := preload("res://assets/global_map/hero_back.png")

const MOVE_SPEED := 7.0
const ARRIVAL_DISTANCE := 0.04

var _hero_icon: MeshInstance3D
var _base_scale: Vector3
var _target_position := Vector3.ZERO
var _is_active := false


func setup(hero_icon: MeshInstance3D) -> void:
	_hero_icon = hero_icon
	if _hero_icon != null:
		_base_scale = _hero_icon.scale


func start_movement(target_position: Vector3) -> void:
	_target_position = target_position
	_is_active = _hero_icon != null


func stop_movement() -> void:
	_is_active = false


func update(delta: float) -> bool:
	if not _is_active or _hero_icon == null:
		return false

	var current_position := _hero_icon.global_position
	var to_target := _target_position - current_position
	if to_target.length() <= ARRIVAL_DISTANCE:
		_hero_icon.global_position = _target_position
		_apply_idle_sprite()
		_is_active = false
		return true

	var movement_direction := to_target.normalized()
	var move_step := MOVE_SPEED * delta
	if move_step >= to_target.length():
		_hero_icon.global_position = _target_position
	else:
		_hero_icon.global_position += movement_direction * move_step

	_apply_movement_sprite(movement_direction)
	return false


func _apply_idle_sprite() -> void:
	_set_texture(FORWARD_TEXTURE)
	_hero_icon.scale = Vector3(absf(_base_scale.x), _base_scale.y, _base_scale.z)


func _apply_movement_sprite(direction: Vector3) -> void:
	if absf(direction.x) >= absf(direction.z):
		_set_texture(RIGHT_TEXTURE)
		if direction.x < 0.0:
			_hero_icon.scale = Vector3(-absf(_base_scale.x), _base_scale.y, _base_scale.z)
		else:
			_hero_icon.scale = Vector3(absf(_base_scale.x), _base_scale.y, _base_scale.z)
		return

	if direction.z < 0.0:
		_set_texture(BACK_TEXTURE)
	else:
		_set_texture(FORWARD_TEXTURE)
	_hero_icon.scale = Vector3(absf(_base_scale.x), _base_scale.y, _base_scale.z)


func _set_texture(texture: Texture2D) -> void:
	if _hero_icon == null:
		return
	var material := _hero_icon.material_override as BaseMaterial3D
	if material == null:
		return
	material.albedo_texture = texture
