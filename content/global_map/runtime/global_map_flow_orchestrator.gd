extends RefCounted
class_name GlobalMapFlowOrchestrator

var _state: GlobalMapRuntimeState
var _hero_controller: HeroIconMovementController
var _fade_presenter: GlobalMapFadeTransitionPresenter
var _transition_service: GlobalMapTransitionService
var _event_icon: MeshInstance3D


func _init(
	state: GlobalMapRuntimeState,
	hero_controller: HeroIconMovementController,
	fade_presenter: GlobalMapFadeTransitionPresenter,
	transition_service: GlobalMapTransitionService,
	event_icon: MeshInstance3D
) -> void:
	_state = state
	_hero_controller = hero_controller
	_fade_presenter = fade_presenter
	_transition_service = transition_service
	_event_icon = event_icon


func process_movement(delta: float, owner: Node) -> void:
	if _state == null or _hero_controller == null:
		return
	if not _state.is_moving:
		return

	var move_result := _hero_controller.move_towards_target(_state.hero_position, _state.event_position, delta)
	_state.hero_position = move_result.get("new_position", _state.hero_position)
	if not move_result.get("arrived", false):
		return

	_state.is_moving = false
	await _play_enter_event_animation(owner)


func request_move_to_event() -> void:
	if _state == null:
		return
	if _state.is_transitioning or _state.is_moving or not _state.is_event_available:
		return
	_state.is_moving = true


func _play_enter_event_animation(owner: Node) -> void:
	if _state == null or _state.is_transitioning:
		return
	_state.is_transitioning = true
	_state.is_event_available = false

	if _hero_controller != null:
		_hero_controller.set_idle_straight()
	if _event_icon != null:
		_event_icon.visible = false

	if _fade_presenter != null:
		await _fade_presenter.play_fade_to_black(owner)
	if _transition_service != null and owner != null:
		_transition_service.open_event_room(owner.get_tree())
