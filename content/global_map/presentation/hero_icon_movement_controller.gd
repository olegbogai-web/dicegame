extends RefCounted
class_name HeroIconMovementController

const HERO_STRAIGHT_TEXTURE := preload("res://assets/global_map/hero_straight.png")
const HERO_RIGHT_TEXTURE := preload("res://assets/global_map/hero_right.png")
const HERO_BACK_TEXTURE := preload("res://assets/global_map/hero_back.png")

const ARRIVAL_THRESHOLD := 0.05

var _hero_icon: MeshInstance3D
var _hero_material: StandardMaterial3D
var _move_speed: float


func _init(hero_icon: MeshInstance3D, move_speed: float) -> void:
	_hero_icon = hero_icon
	_move_speed = move_speed
	if _hero_icon != null and _hero_icon.material_override is StandardMaterial3D:
		_hero_material = _hero_icon.material_override as StandardMaterial3D


func move_towards_target(current_position: Vector3, target_position: Vector3, delta: float) -> Dictionary:
	if _hero_icon == null:
		return {
			"new_position": current_position,
			"arrived": true,
		}

	var to_target := target_position - current_position
	if to_target.length() <= ARRIVAL_THRESHOLD:
		_set_hero_orientation(Vector3.ZERO)
		_hero_icon.position = target_position
		return {
			"new_position": target_position,
			"arrived": true,
		}

	var direction := to_target.normalized()
	_set_hero_orientation(direction)
	var travel_distance := _move_speed * delta
	var next_position := current_position + direction * minf(travel_distance, to_target.length())
	_hero_icon.position = next_position

	return {
		"new_position": next_position,
		"arrived": next_position.distance_to(target_position) <= ARRIVAL_THRESHOLD,
	}


func set_idle_straight() -> void:
	_set_hero_texture(HERO_STRAIGHT_TEXTURE)
	_set_horizontal_mirror(false)


func _set_hero_orientation(direction: Vector3) -> void:
	if direction == Vector3.ZERO:
		_set_hero_texture(HERO_STRAIGHT_TEXTURE)
		_set_horizontal_mirror(false)
		return

	if absf(direction.x) >= absf(direction.z):
		_set_hero_texture(HERO_RIGHT_TEXTURE)
		_set_horizontal_mirror(direction.x < 0.0)
		return

	if direction.z < 0.0:
		_set_hero_texture(HERO_BACK_TEXTURE)
		_set_horizontal_mirror(false)
		return

	_set_hero_texture(HERO_STRAIGHT_TEXTURE)
	_set_horizontal_mirror(false)


func _set_hero_texture(texture: Texture2D) -> void:
	if _hero_material == null:
		return
	if _hero_material.albedo_texture == texture:
		return
	_hero_material.albedo_texture = texture


func _set_horizontal_mirror(is_mirrored: bool) -> void:
	if _hero_icon == null:
		return
	var hero_scale := _hero_icon.scale
	hero_scale.x = absf(hero_scale.x) * (-1.0 if is_mirrored else 1.0)
	_hero_icon.scale = hero_scale
