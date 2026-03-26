extends RefCounted
class_name GlobalMapFlowOrchestrator

const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const GlobalMapEventIconPresenter = preload("res://content/global_map/presentation/global_map_event_icon_presenter.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const Player = preload("res://content/entities/player.gd")
const PlayerBaseStat = preload("res://content/entities/player_base_stat.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")

const EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"
const HERO_MOVE_SPEED := 4.75
const EVENT_PICK_RADIUS := 55.0
const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3(5.0, 5.0, 5.0)
const GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER := 4.0
const GLOBAL_MAP_DICE_LOG_PREFIX := "[GlobalMapDice]"

var _owner: Node3D
var _camera: Camera3D
var _event_icon: MeshInstance3D
var _board: BoardController
var _road_nodes: Array[Node3D] = []
var _hero_movement := HeroIconMovementController.new()
var _fade_presenter := GlobalMapFadeTransitionPresenter.new()
var _event_presenter := GlobalMapEventIconPresenter.new()
var _state := GlobalMapRuntimeState.new()
var _path_points: Array[Vector3] = []
var _path_index := 0
var _is_event_hovered := false
var _is_global_map_roll_pending := false


func configure(
	owner: Node3D,
	camera: Camera3D,
	hero_icon: MeshInstance3D,
	event_icon: MeshInstance3D,
	road_nodes: Array[Node3D],
	board: BoardController
) -> void:
	_owner = owner
	_camera = camera
	_event_icon = event_icon
	_board = board
	_road_nodes = road_nodes.duplicate()
	_hero_movement.configure(hero_icon)
	_fade_presenter.configure(owner)
	_event_presenter.configure(event_icon)
	_build_path_points()
	_restore_persisted_state()
	_schedule_global_map_dice_roll_if_needed()


func process(delta: float) -> void:
	if _is_global_map_roll_pending:
		_is_global_map_roll_pending = false
		_deferred_roll_global_map_dice()
	if _state.is_transition_in_progress:
		return
	if not _state.hero_move_started:
		return
	if _path_index >= _path_points.size():
		return

	var remaining_step := HERO_MOVE_SPEED * delta
	while remaining_step > 0.0 and _path_index < _path_points.size():
		var current_position := _hero_movement.get_ground_position()
		var target_position := _path_points[_path_index]
		_hero_movement.update_direction(current_position, target_position)

		var next_position := current_position.move_toward(target_position, remaining_step)
		var moved_distance := current_position.distance_to(next_position)
		remaining_step -= moved_distance
		_hero_movement.set_world_position(next_position)
		if next_position.distance_to(target_position) > 0.02:
			break
		_hide_passed_road_dash(_path_index)
		_path_index += 1
	if _path_index >= _path_points.size():
		_on_event_reached()


func handle_input(event: InputEvent) -> void:
	if _state.is_transition_in_progress:
		return
	if _state.event_reached:
		return
	if _path_points.is_empty():
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		_update_event_hover(mouse_motion.position)
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not _is_event_icon_clicked(mouse_event.position):
		return

	_state.hero_move_started = true
	_path_index = 0


func _is_event_icon_clicked(mouse_position: Vector2) -> bool:
	if _camera == null or _event_icon == null:
		return false
	if not _event_icon.visible:
		return false
	var projected := _camera.unproject_position(_event_icon.global_position)
	return projected.distance_to(mouse_position) <= EVENT_PICK_RADIUS


func _build_path_points() -> void:
	_path_points.clear()
	for road_node in _road_nodes:
		if road_node == null:
			continue
		road_node.visible = true
		_path_points.append(road_node.global_position)
	if _event_icon != null:
		_path_points.append(_event_icon.global_position)


func _on_event_reached() -> void:
	if _state.event_reached:
		return
	_state.event_reached = true
	_state.is_transition_in_progress = true
	await _play_enter_room_animation()
	_persist_current_state()
	_owner.get_tree().change_scene_to_file(EVENT_ROOM_SCENE_PATH)


func _play_enter_room_animation() -> void:
	_event_presenter.set_hovered(false)
	_hero_movement.snap_to_idle()
	_event_presenter.hide()
	await _fade_presenter.play_fade_out()


func _hide_passed_road_dash(reached_path_index: int) -> void:
	if reached_path_index < 0 or reached_path_index >= _road_nodes.size():
		return
	var road_node := _road_nodes[reached_path_index]
	if road_node == null:
		return
	road_node.visible = false


func _update_event_hover(mouse_position: Vector2) -> void:
	var should_be_hovered := _is_event_icon_clicked(mouse_position)
	if should_be_hovered == _is_event_hovered:
		return
	_is_event_hovered = should_be_hovered
	_event_presenter.set_hovered(_is_event_hovered)


func _restore_persisted_state() -> void:
	if not GlobalMapRuntimeState.has_snapshot():
		return
	var snapshot := GlobalMapRuntimeState.load_snapshot()
	_path_index = int(snapshot.get("path_index", 0))
	_state.hero_move_started = bool(snapshot.get("hero_move_started", false))
	_state.event_reached = bool(snapshot.get("event_reached", false))
	_state.is_transition_in_progress = false
	var saved_position = snapshot.get("hero_world_position", null)
	if saved_position is Vector3:
		_hero_movement.set_world_position(saved_position as Vector3)
	var dash_visibility := snapshot.get("road_visibility", []) as Array
	for index in range(min(_road_nodes.size(), dash_visibility.size())):
		var road_node := _road_nodes[index]
		if road_node == null:
			continue
		road_node.visible = bool(dash_visibility[index])
	if _state.event_reached:
		_event_presenter.hide()


func _persist_current_state() -> void:
	var dash_visibility: Array[bool] = []
	for road_node in _road_nodes:
		dash_visibility.append(road_node != null and road_node.visible)
	GlobalMapRuntimeState.save_snapshot({
		"path_index": _path_index,
		"hero_move_started": _state.hero_move_started,
		"event_reached": _state.event_reached,
		"hero_world_position": _hero_movement.get_ground_position(),
		"road_visibility": dash_visibility,
	})


func _schedule_global_map_dice_roll_if_needed() -> void:
	var should_roll := GlobalMapRuntimeState.has_snapshot()
	if not should_roll:
		print("%s Первый вход на глобальную карту: бросок кубов пропущен." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	_is_global_map_roll_pending = true


func _deferred_roll_global_map_dice() -> void:
	if _board == null:
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но board не найден." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	var player := _resolve_or_create_runtime_player()
	if player == null:
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но игрок не инициализирован." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	if player.runtime_cube_global_map.is_empty():
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но у игрока нет runtime_cube_global_map." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return

	var requests: Array[DiceThrowRequest] = []
	for definition in player.runtime_cube_global_map:
		if definition == null:
			push_warning("%s Игра попыталась бросить куб, но определение куба пустое." % GLOBAL_MAP_DICE_LOG_PREFIX)
			continue
		requests.append(_build_global_map_throw_request(definition))
		print("%s брошен куб (%s)." % [GLOBAL_MAP_DICE_LOG_PREFIX, _format_faces_for_debug(definition)])

	if requests.is_empty():
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но валидных запросов нет." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return

	var spawned_dice := _board.throw_dice(requests)
	if spawned_dice.is_empty():
		push_warning("%s Игра попыталась бросить кубы глобальной карты, но бросок не создал ни одного куба." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	for dice_body in spawned_dice:
		if dice_body == null:
			continue
		dice_body.linear_velocity.y *= GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER


func _build_global_map_throw_request(definition: DiceDefinition) -> DiceThrowRequest:
	var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
	request.extra_size_multiplier = GLOBAL_MAP_DICE_SIZE_MULTIPLIER
	request.metadata["owner"] = "global_map"
	request.metadata["definition"] = definition
	return request


func _resolve_or_create_runtime_player() -> Player:
	var saved_player = GlobalMapRuntimeState.load_runtime_player()
	if saved_player != null:
		return saved_player
	var base_stat := PlayerBaseStat.new()
	base_stat.player_id = "global_map_runtime_player"
	base_stat.display_name = "GlobalMapRuntimePlayer"
	var player := Player.new(base_stat)
	GlobalMapRuntimeState.save_runtime_player(player)
	return player


func _format_faces_for_debug(definition: DiceDefinition) -> String:
	if definition == null:
		return "unknown"
	var face_values: PackedStringArray = PackedStringArray()
	for face in definition.faces:
		if face == null:
			face_values.append("null")
		else:
			face_values.append(face.text_value)
	return ", ".join(face_values)
