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
const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")
const Dice = preload("res://content/dice/dice.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")

const EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"
const BATTLE_ROOM_SCENE_PATH := "res://scenes/new_battle_table.tscn"
const HERO_MOVE_SPEED := 4.75
const EVENT_PICK_RADIUS := 55.0
const GLOBAL_MAP_DICE_SIZE_MULTIPLIER := Vector3(5.0, 5.0, 5.0)
const GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER := 4.0
const GLOBAL_MAP_DICE_LOG_PREFIX := "[GlobalMapDice]"
const MAP_WALL_MARGIN := 1.5
const MIN_MARKER_DISTANCE := 3.0
const MARKER_DELTA_X_MIN := 0.0
const MARKER_DELTA_X_MAX := 3.0
const MARKER_DELTA_Z_MIN := -5.0
const MARKER_DELTA_Z_MAX := 5.0
const MAX_MARKER_POSITION_ATTEMPTS := 64

class MarkerEntry:
	extends RefCounted

	var node: MeshInstance3D
	var presenter := GlobalMapEventIconPresenter.new()
	var room_scene_path := ""


var _owner: Node3D
var _camera: Camera3D
var _background: MeshInstance3D
var _marker_template: MeshInstance3D
var _board: BoardController
var _hero_movement := HeroIconMovementController.new()
var _fade_presenter := GlobalMapFadeTransitionPresenter.new()
var _state := GlobalMapRuntimeState.new()
var _is_global_map_roll_pending := false
var _is_waiting_global_map_dice_stop := false
var _global_map_dice: Array[Dice] = []
var _markers: Array[MarkerEntry] = []
var _hovered_marker: MarkerEntry
var _target_marker: MarkerEntry
var _transition_target_scene_path := ""
var _rng := RandomNumberGenerator.new()


func configure(
	owner: Node3D,
	camera: Camera3D,
	background: MeshInstance3D,
	hero_icon: MeshInstance3D,
	marker_template: MeshInstance3D,
	board: BoardController
) -> void:
	_owner = owner
	_camera = camera
	_background = background
	_marker_template = marker_template
	_board = board
	_hero_movement.configure(hero_icon)
	_fade_presenter.configure(owner)
	_rng.randomize()
	_restore_persisted_state()
	_schedule_global_map_dice_roll_if_needed()


func process(delta: float) -> void:
	if _is_global_map_roll_pending:
		_is_global_map_roll_pending = false
		_deferred_roll_global_map_dice()
	if _is_waiting_global_map_dice_stop and _are_global_map_dice_stopped():
		_is_waiting_global_map_dice_stop = false
		_spawn_markers_from_global_map_dice()
	if _state.is_transition_in_progress:
		return
	if _target_marker == null:
		return

	var current_position := _hero_movement.get_ground_position()
	var target_position := _target_marker.node.global_position
	_hero_movement.update_direction(current_position, target_position)
	var next_position := current_position.move_toward(target_position, HERO_MOVE_SPEED * delta)
	_hero_movement.set_world_position(next_position)
	if next_position.distance_to(target_position) > 0.02:
		return
	_on_marker_reached(_target_marker)


func handle_input(event: InputEvent) -> void:
	if _state.is_transition_in_progress:
		return
	if _is_waiting_global_map_dice_stop:
		return
	if _markers.is_empty():
		return
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		_update_marker_hover(mouse_motion.position)
		return
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var clicked_marker := _pick_marker(mouse_event.position)
	if clicked_marker == null:
		return
	_target_marker = clicked_marker


func _update_marker_hover(mouse_position: Vector2) -> void:
	var hovered_marker := _pick_marker(mouse_position)
	if hovered_marker == _hovered_marker:
		return
	if _hovered_marker != null:
		_hovered_marker.presenter.set_hovered(false)
	_hovered_marker = hovered_marker
	if _hovered_marker != null:
		_hovered_marker.presenter.set_hovered(true)


func _pick_marker(mouse_position: Vector2) -> MarkerEntry:
	if _camera == null:
		return null
	for marker in _markers:
		if marker == null or marker.node == null or not marker.node.visible:
			continue
		var projected := _camera.unproject_position(marker.node.global_position)
		if projected.distance_to(mouse_position) <= EVENT_PICK_RADIUS:
			return marker
	return null


func _on_marker_reached(marker: MarkerEntry) -> void:
	if marker == null:
		return
	_state.is_transition_in_progress = true
	_transition_target_scene_path = marker.room_scene_path
	for entry in _markers:
		if entry == null:
			continue
		entry.presenter.set_hovered(false)
		entry.node.visible = false
	await _fade_presenter.play_fade_out()
	_persist_current_state()
	var target_scene_path := _transition_target_scene_path
	if target_scene_path.is_empty():
		target_scene_path = EVENT_ROOM_SCENE_PATH
	_owner.get_tree().change_scene_to_file(target_scene_path)


func _restore_persisted_state() -> void:
	if not GlobalMapRuntimeState.has_snapshot():
		return
	var snapshot := GlobalMapRuntimeState.load_snapshot()
	_state.is_transition_in_progress = false
	var saved_position = snapshot.get("hero_world_position", null)
	if saved_position is Vector3:
		_hero_movement.set_world_position(saved_position as Vector3)


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

	for marker in _markers:
		if marker != null and marker.node != null and is_instance_valid(marker.node):
			marker.node.queue_free()
	_markers.clear()
	_hovered_marker = null
	_target_marker = null
	_global_map_dice.clear()

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
		if not dice_body is Dice:
			continue
		var dice := dice_body as Dice
		dice.linear_velocity.y *= GLOBAL_MAP_DICE_THROW_HEIGHT_MULTIPLIER
		_global_map_dice.append(dice)
	if _global_map_dice.is_empty():
		push_warning("%s На глобальной карте не найдено ни одного валидного куба Dice после броска." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	_is_waiting_global_map_dice_stop = true


func _are_global_map_dice_stopped() -> bool:
	for dice in _global_map_dice:
		if dice == null or not is_instance_valid(dice):
			continue
		if not DiceMotionState.is_fully_stopped(dice):
			return false
	return true


func _spawn_markers_from_global_map_dice() -> void:
	if _marker_template == null:
		push_warning("%s Шаблон метки не найден, генерация меток пропущена." % GLOBAL_MAP_DICE_LOG_PREFIX)
		return
	var current_anchor := _hero_movement.get_ground_position()
	var occupied_positions: Array[Vector3] = [current_anchor]
	for dice in _global_map_dice:
		if dice == null or not is_instance_valid(dice):
			continue
		var marker_position := _find_marker_position(current_anchor, occupied_positions)
		if marker_position == null:
			push_warning("%s Не удалось подобрать позицию метки по правилам размещения." % GLOBAL_MAP_DICE_LOG_PREFIX)
			continue
		occupied_positions.append(marker_position as Vector3)
		var marker := _create_marker(marker_position as Vector3, _resolve_room_for_dice(dice))
		if marker != null:
			_markers.append(marker)
	for dice in _global_map_dice:
		if dice != null and is_instance_valid(dice):
			dice.queue_free()
	_global_map_dice.clear()


func _find_marker_position(current_anchor: Vector3, occupied_positions: Array[Vector3]) -> Variant:
	var map_bounds := _resolve_map_bounds()
	var min_x := float(map_bounds.get("min_x", current_anchor.x))
	var max_x := float(map_bounds.get("max_x", current_anchor.x + MARKER_DELTA_X_MAX))
	var min_z := float(map_bounds.get("min_z", current_anchor.z + MARKER_DELTA_Z_MIN))
	var max_z := float(map_bounds.get("max_z", current_anchor.z + MARKER_DELTA_Z_MAX))

	for _attempt in MAX_MARKER_POSITION_ATTEMPTS:
		var delta_x := _rng.randf_range(MARKER_DELTA_X_MIN, MARKER_DELTA_X_MAX)
		var delta_z := _rng.randf_range(MARKER_DELTA_Z_MIN, MARKER_DELTA_Z_MAX)
		var candidate := Vector3(current_anchor.x + delta_x, current_anchor.y, current_anchor.z + delta_z)
		candidate.x = clampf(candidate.x, min_x, max_x)
		candidate.z = clampf(candidate.z, min_z, max_z)
		if candidate.x < current_anchor.x:
			continue
		if absf(candidate.z - current_anchor.z) > absf(MARKER_DELTA_Z_MAX):
			continue
		if candidate.x - current_anchor.x < MARKER_DELTA_X_MIN or candidate.x - current_anchor.x > MARKER_DELTA_X_MAX:
			continue
		if not _is_position_far_enough(candidate, occupied_positions):
			continue
		return candidate
	return null


func _resolve_map_bounds() -> Dictionary:
	var fallback_center := _hero_movement.get_ground_position()
	if _background == null or _background.mesh == null:
		return {
			"min_x": fallback_center.x - 100.0,
			"max_x": fallback_center.x + 100.0,
			"min_z": fallback_center.z - 100.0,
			"max_z": fallback_center.z + 100.0,
		}

	var aabb := _background.mesh.get_aabb()
	var corners := [
		Vector3(aabb.position.x, 0.0, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, 0.0, aabb.position.z),
		Vector3(aabb.position.x, 0.0, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, 0.0, aabb.position.z + aabb.size.z),
	]
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for corner in corners:
		var world_corner := _background.to_global(corner)
		min_x = minf(min_x, world_corner.x)
		max_x = maxf(max_x, world_corner.x)
		min_z = minf(min_z, world_corner.z)
		max_z = maxf(max_z, world_corner.z)
	return {
		"min_x": min_x + MAP_WALL_MARGIN,
		"max_x": max_x - MAP_WALL_MARGIN,
		"min_z": min_z + MAP_WALL_MARGIN,
		"max_z": max_z - MAP_WALL_MARGIN,
	}


func _is_position_far_enough(candidate: Vector3, occupied_positions: Array[Vector3]) -> bool:
	for occupied in occupied_positions:
		if candidate.distance_to(occupied) < MIN_MARKER_DISTANCE:
			return false
	return true


func _create_marker(world_position: Vector3, room_scene_path: String) -> MarkerEntry:
	if _owner == null or _marker_template == null:
		return null
	var marker_node := _marker_template.duplicate() as MeshInstance3D
	if marker_node == null:
		return null
	marker_node.visible = true
	marker_node.global_position = world_position
	_owner.add_child(marker_node)
	var marker := MarkerEntry.new()
	marker.node = marker_node
	marker.room_scene_path = room_scene_path
	marker.presenter.configure(marker_node)
	return marker


func _resolve_room_for_dice(dice: Dice) -> String:
	var top_face := dice.get_top_face()
	if top_face == null:
		return EVENT_ROOM_SCENE_PATH
	var value := top_face.text_value.to_lower()
	if value == "swords":
		return BATTLE_ROOM_SCENE_PATH
	return EVENT_ROOM_SCENE_PATH


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
		return "empty"
	var face_values: Array[String] = []
	for face in definition.faces:
		if face == null:
			continue
		face_values.append(face.text_value)
	if face_values.is_empty():
		return "no_faces"
	return ", ".join(face_values)
