extends RefCounted
class_name GlobalMapFlowOrchestrator

const MOVE_SPEED := 7.5
const EVENT_REACH_DISTANCE := 0.05

var _hero_icon: MeshInstance3D
var _event_icon: MeshInstance3D
var _hero_movement_controller: HeroIconMovementController

var _is_moving_to_event := false


func setup(hero_icon: MeshInstance3D, event_icon: MeshInstance3D, hero_movement_controller: HeroIconMovementController) -> void:
	_hero_icon = hero_icon
	_event_icon = event_icon
	_hero_movement_controller = hero_movement_controller
	if _hero_movement_controller != null:
		_hero_movement_controller.setup(_hero_icon)
		_hero_movement_controller.apply_idle_sprite()


func begin_move_to_event() -> void:
	if _hero_icon == null or _event_icon == null:
		return
	_is_moving_to_event = true


func process_move(delta: float) -> bool:
	if not _is_moving_to_event:
		return false
	if _hero_icon == null or _event_icon == null:
		_is_moving_to_event = false
		return false

	var from_position := _hero_icon.global_position
	var target_position := _event_icon.global_position
	var next_position := from_position.move_toward(target_position, MOVE_SPEED * delta)
	if _hero_movement_controller != null:
		_hero_movement_controller.update_sprite_for_motion(from_position, next_position)
	_hero_icon.global_position = next_position

	if next_position.distance_to(target_position) <= EVENT_REACH_DISTANCE:
		_hero_icon.global_position = target_position
		_is_moving_to_event = false
		if _hero_movement_controller != null:
			_hero_movement_controller.apply_idle_sprite()
		return true
	return false


func is_busy() -> bool:
	return _is_moving_to_event
