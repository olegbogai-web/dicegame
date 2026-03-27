extends RefCounted
class_name GlobalMapFlowOrchestrator

const HeroIconMovementController = preload("res://content/global_map/presentation/hero_icon_movement_controller.gd")
const GlobalMapFadeTransitionPresenter = preload("res://content/global_map/presentation/global_map_fade_transition_presenter.gd")
const GlobalMapEventIconPresenter = preload("res://content/global_map/presentation/global_map_event_icon_presenter.gd")
const GlobalMapMarkerPresenter = preload("res://content/global_map/presentation/global_map_marker_presenter.gd")
const GlobalMapMarkerSpawnService = preload("res://content/global_map/runtime/global_map_marker_spawn_service.gd")
const GlobalMapMarkerRoomLinkResolver = preload("res://content/global_map/routing/global_map_marker_room_link_resolver.gd")
const GlobalMapRuntimeState = preload("res://content/global_map/runtime/global_map_runtime_state.gd")
const Player = preload("res://content/entities/player.gd")
const PlayerBaseStat = preload("res://content/entities/player_base_stat.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const Dice = preload("res://content/dice/dice.gd")

const START_EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"
const HERO_MOVE_SPEED := 4.75
const EVENT_PICK_RADIUS := 55.0
const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3(5.0, 5.0, 5.0)
const GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER := 4.0
const GLOBAL_MAP_DICE_LOG_PREFIX := "[GlobalMapDice]"

var _owner: Node3D
var _camera: Camera3D
var _event_icon: MeshInstance3D
var _background: MeshInstance3D
var _board: BoardController
var _road_nodes: Array[Node3D] = []
var _hero_movement := HeroIconMovementController.new()
var _fade_presenter := GlobalMapFadeTransitionPresenter.new()
var _event_presenter := GlobalMapEventIconPresenter.new()
var _marker_presenter := GlobalMapMarkerPresenter.new()
var _marker_spawn_service := GlobalMapMarkerSpawnService.new()
var _marker_link_resolver := GlobalMapMarkerRoomLinkResolver.new()
var _state := GlobalMapRuntimeState.new()
var _path_points: Array[Vector3] = []
var _start_path_points: Array[Vector3] = []
var _path_index := 0
var _is_event_hovered := false
var _is_global_map_roll_pending := false
var _is_waiting_for_roll_results := false
var _rolled_global_map_dice: Array[Dice] = []
var _pending_room_scene_path := ""


func configure(
	owner: Node3D,
	camera: Camera3D,
	hero_icon: MeshInstance3D,
	event_icon: MeshInstance3D,
	background: MeshInstance3D,
	road_nodes: Array[Node3D],
	board: BoardController
) -> void:
	_owner = owner
	_camera = camera
	_event_icon = event_icon
	_background = background
	_board = board
	_road_nodes = road_nodes.duplicate()
	_hero_movement.configure(hero_icon)
	_fade_presenter.configure(owner)
	_event_presenter.configure(event_icon)
	_marker_presenter.configure(owner, event_icon, camera)
	_build_start_path_points()
	_restore_persisted_state()
	_schedule_global_map_dice_roll_if_needed()


func process(delta: float) -> void:
	_process_global_map_roll_state()
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
		_on_target_marker_reached()


func handle_input(event: InputEvent) -> void:
	if _state.is_transition_in_progress:
		return
	if _state.hero_move_started:
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		_update_event_hover(mouse_motion.position)
		_marker_presenter.set_hovered_marker(mouse_motion.position)
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if _try_pick_dynamic_marker(mouse_event.position):
		return
	if not _is_event_icon_clicked(mouse_event.position):
		return

	_pending_room_scene_path = START_EVENT_ROOM_SCENE_PATH
	_path_points = _start_path_points.duplicate()
	_path_index = 0
	_state.hero_move_started = true


func _try_pick_dynamic_marker(mouse_position: Vector2) -> bool:
	var picked_marker := _marker_presenter.pick_marker(mouse_position)
	if picked_marker.is_empty():
		return false
	var marker_node := picked_marker.get("node") as Node3D
	if marker_node == null:
		return false
	_pending_room_scene_path = String(picked_marker.get("scene_path", ""))
	_path_points = [marker_node.global_position]
	_path_index = 0
	_state.hero_move_started = true
	return true


func _is_event_icon_clicked(mouse_position: Vector2) -> bool:
	if _camera == null or _event_icon == null:
		return false
	if not _event_icon.visible:
		return false
	var projected := _camera.unproject_position(_event_icon.global_position)
	return projected.distance_to(mouse_position) <= EVENT_PICK_RADIUS


func _build_start_path_points() -> void:
	_start_path_points.clear()
	for road_node in _road_nodes:
		if road_node == null:
			continue
		road_node.visible = true
		_start_path_points.append(road_node.global_position)
	if _event_icon != null:
		_start_path_points.append(_event_icon.global_position)


func _on_target_marker_reached() -> void:
	if _state.is_transition_in_progress:
		return
	_state.is_transition_in_progress = true
	await _play_enter_room_animation()
	_persist_current_state()
	var next_scene_path := _pending_room_scene_path if not _pending_room_scene_path.is_empty() else START_EVENT_ROOM_SCENE_PATH
	_owner.get_tree().change_scene_to_file(next_scene_path)


func _play_enter_room_animation() -> void:
	_event_presenter.set_hovered(false)
	_marker_presenter.clear_hovered_marker()
	_hero_movement.snap_to_idle()
	await _fade_presenter.play_fade_out()


func _hide_passed_road_dash(reached_path_index: int) -> void:
	if reached_path_index < 0 or reached_path_index >= _road_nodes.size():
		return
	if _path_points.size() != _start_path_points.size():
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
	_state.hero_move_started = false
	_state.is_transition_in_progress = false
	var saved_position = snapshot.get("hero_world_position", null)
	if saved_position is Vector3:
		_hero_movement.set_world_position(saved_position as Vector3)
	for road_node in _road_nodes:
		if road_node == null:
			continue
		road_node.visible = true
	_path_points.clear()
	_path_index = 0


func _persist_current_state() -> void:
	GlobalMapRuntimeState.save_snapshot({
		"hero_world_position": _hero_movement.get_ground_position(),
	})


func _schedule_global_map_dice_roll_if_needed() -> void:
	var should_roll := GlobalMapRuntimeState.has_snapshot()
	if not should_roll:
		print("%s Первый вход на глобальную карту: бросок кубов пропущен." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	_is_global_map_roll_pending = true


func _process_global_map_roll_state() -> void:
	if _is_global_map_roll_pending:
		_is_global_map_roll_pending = false
		_deferred_roll_global_map_dice()
		return
	if not _is_waiting_for_roll_results:
		return
	for dice in _rolled_global_map_dice:
		if dice == null or not is_instance_valid(dice):
			return
		if not dice.has_completed_first_stop():
			return
	_is_waiting_for_roll_results = false
	_spawn_markers_for_roll_result()


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
	_rolled_global_map_dice.clear()
	for dice_body in spawned_dice:
		if dice_body == null:
			continue
		dice_body.linear_velocity.y *= GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER
		if dice_body is Dice:
			_rolled_global_map_dice.append(dice_body as Dice)
	_is_waiting_for_roll_results = not _rolled_global_map_dice.is_empty()


func _spawn_markers_for_roll_result() -> void:
	if _rolled_global_map_dice.is_empty():
		return
	var marker_points := _marker_spawn_service.build_spawn_points(
		_background,
		_hero_movement.get_ground_position(),
		_rolled_global_map_dice.size()
	)
	if marker_points.is_empty():
		push_warning("%s Не удалось разместить новые метки на карте." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	var marker_specs: Array[Dictionary] = []
	for index in range(min(_rolled_global_map_dice.size(), marker_points.size())):
		var dice := _rolled_global_map_dice[index]
		var marker_data := _marker_link_resolver.resolve_marker_for_face(dice.get_top_face())
		marker_data["position"] = marker_points[index]
		marker_specs.append(marker_data)
	_marker_presenter.show_markers(marker_specs)


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
	var values: PackedStringArray = []
	for face in definition.faces:
		if face == null:
			values.append("null")
			continue
		values.append(face.text_value)
	return ", ".join(values)
