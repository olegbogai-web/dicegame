@tool
extends RigidBody3D
class_name Dice

const FACE_NAMES: Array[StringName] = [&"Front", &"Back", &"Right", &"Left", &"Top", &"Bottom"]
const FACE_NORMALS: Array[Vector3] = [
	Vector3.FORWARD,
	Vector3.BACK,
	Vector3.RIGHT,
	Vector3.LEFT,
	Vector3.UP,
	Vector3.DOWN,
]
const DEFAULT_FRICTION := 0.25
const DEFAULT_BOUNCE := 0.75
const DEFAULT_LINEAR_DAMP := 0.25
const DEFAULT_ANGULAR_DAMP := 0.25
const POST_FIRST_STOP_GRAVITY_MULTIPLIER := 5.0

const DiceNodeGraphScript = preload("res://content/dice/runtime/dice_node_graph.gd")
const DicePhysicsRuntimeScript = preload("res://content/dice/runtime/dice_physics_runtime.gd")
const DiceVisualRuntimeScript = preload("res://content/dice/runtime/dice_visual_runtime.gd")
const DiceDefinitionBindingScript = preload("res://content/dice/runtime/dice_definition_binding.gd")
const DiceDragControllerScript = preload("res://content/dice/runtime/dice_drag_controller.gd")
const DiceOrientationServiceScript = preload("res://content/dice/runtime/dice_orientation_service.gd")
const DiceSlotSnapControllerScript = preload("res://content/dice/runtime/dice_slot_snap_controller.gd")
const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")
const BoardController = preload("res://ui/scripts/board_controller.gd")

@export var definition: DiceDefinition
@export var extra_size_multiplier: Vector3 = Vector3.ONE

@export_category("Drag")
@export var drag_lift_height: float = 0.9

@export_category("Ability Slot Snap")
@export var ability_snap_distance: float = 1.5
@export var ability_snap_speed: float = 6.5

var _node_graph: DiceNodeGraph
var _physics_runtime: DicePhysicsRuntime
var _visual_runtime: DiceVisualRuntime
var _definition_binding: DiceDefinitionBinding
var _drag_controller: DiceDragController
var _orientation_service: DiceOrientationService
var _slot_snap_controller: DiceSlotSnapController
var _has_completed_first_stop := false
var _base_gravity_scale := 1.0
var _was_dragging_on_previous_physics_frame := false
var _is_returning_to_board := false


func _enter_tree() -> void:
	_setup_components()
	_base_gravity_scale = gravity_scale
	_node_graph.ensure_nodes(self, FACE_NAMES)
	_physics_runtime.apply_defaults(
		self,
		DEFAULT_FRICTION,
		DEFAULT_BOUNCE,
		DEFAULT_LINEAR_DAMP,
		DEFAULT_ANGULAR_DAMP
	)
	_definition_binding.bind(definition)
	_sync_runtime()


func _ready() -> void:
	_setup_components()
	_base_gravity_scale = gravity_scale
	_connect_runtime_signals()
	_node_graph.ensure_nodes(self, FACE_NAMES)
	_physics_runtime.apply_defaults(
		self,
		DEFAULT_FRICTION,
		DEFAULT_BOUNCE,
		DEFAULT_LINEAR_DAMP,
		DEFAULT_ANGULAR_DAMP
	)
	_definition_binding.bind(definition)
	_sync_runtime()
	input_ray_pickable = true
	lock_rotation = false
	set_physics_process(true)


func _exit_tree() -> void:
	_setup_components()
	_drag_controller.stop_dragging(self)
	_definition_binding.unbind()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_setup_components()
		_physics_runtime.apply_defaults(
			self,
			DEFAULT_FRICTION,
			DEFAULT_BOUNCE,
			DEFAULT_LINEAR_DAMP,
			DEFAULT_ANGULAR_DAMP
		)
		_definition_binding.bind(definition)
		_sync_runtime()


func _get_configuration_warnings() -> PackedStringArray:
	_setup_components()
	return _definition_binding.get_configuration_warnings(definition)


func _input_event(camera: Camera3D, event: InputEvent, position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	_setup_components()
	if StringName(get_meta(&"owner", &"")) != &"player":
		return
	var allow_drag_without_sleep := _slot_snap_controller.prepare_for_manual_drag(self, event)
	if _has_completed_first_stop:
		allow_drag_without_sleep = true
	if allow_drag_without_sleep:
		get_viewport().set_input_as_handled()
	_drag_controller.handle_input_event(self, camera, event, position, drag_lift_height, allow_drag_without_sleep)


func _physics_process(delta: float) -> void:
	_setup_components()
	_drag_controller.physics_process(self)
	var is_dragging := _drag_controller.is_dragging()
	_slot_snap_controller.physics_process(self, delta, is_dragging)
	if _was_dragging_on_previous_physics_frame and not is_dragging:
		_try_return_to_board_if_outside()
	_was_dragging_on_previous_physics_frame = is_dragging
	if _has_completed_first_stop and not is_dragging:
		lock_rotation = true


func get_top_face_index() -> int:
	_setup_components()
	return _orientation_service.get_top_face_index(self, FACE_NORMALS)


func get_top_face() -> DiceFaceDefinition:
	if definition == null:
		return null
	return definition.get_face(get_top_face_index())


func get_top_face_value() -> int:
	var top_face := get_top_face()
	if top_face == null:
		return -1
	return top_face.text_value.to_int()


func get_match_tags() -> PackedStringArray:
	var resolved_tags := PackedStringArray()
	if definition != null and not definition.dice_name.is_empty():
		resolved_tags.append(definition.dice_name)
	var top_face := get_top_face()
	if top_face != null and not top_face.text_value.is_empty():
		resolved_tags.append(top_face.text_value)
	return resolved_tags


func assign_ability_slot(slot_id: StringName, target_position: Vector3) -> void:
	_setup_components()
	_slot_snap_controller.assign_slot(self, slot_id, target_position)


func clear_ability_slot() -> void:
	_setup_components()
	_slot_snap_controller.clear_slot(self)


func get_assigned_ability_slot_id() -> StringName:
	_setup_components()
	return _slot_snap_controller.get_assigned_slot_id()


func is_snapped_to_ability_slot() -> bool:
	_setup_components()
	return _slot_snap_controller.is_snapped()


func is_being_dragged() -> bool:
	_setup_components()
	return _drag_controller.is_dragging()


func has_completed_first_stop() -> bool:
	return _has_completed_first_stop


func _setup_components() -> void:
	if _node_graph == null:
		_node_graph = DiceNodeGraphScript.new()
	if _physics_runtime == null:
		_physics_runtime = DicePhysicsRuntimeScript.new()
	if _visual_runtime == null:
		_visual_runtime = DiceVisualRuntimeScript.new()
	if _definition_binding == null:
		_definition_binding = DiceDefinitionBindingScript.new()
		_definition_binding.definition_changed.connect(_on_definition_changed)
	if _drag_controller == null:
		_drag_controller = DiceDragControllerScript.new()
	if _orientation_service == null:
		_orientation_service = DiceOrientationServiceScript.new()
	if _slot_snap_controller == null:
		_slot_snap_controller = DiceSlotSnapControllerScript.new()
	_slot_snap_controller.configure(ability_snap_distance, ability_snap_speed)


func _connect_runtime_signals() -> void:
	if not sleeping_state_changed.is_connected(_on_sleeping_state_changed):
		sleeping_state_changed.connect(_on_sleeping_state_changed)


func _sync_runtime() -> void:
	if not is_inside_tree():
		return

	_node_graph.ensure_nodes(self, FACE_NAMES)
	_physics_runtime.refresh_collision_shape(self, _node_graph, definition, extra_size_multiplier)
	_visual_runtime.refresh(self, _node_graph, definition, extra_size_multiplier, FACE_NORMALS)
	update_configuration_warnings()


func _on_definition_changed() -> void:
	_sync_runtime()


func _on_sleeping_state_changed() -> void:
	if not sleeping:
		if _has_completed_first_stop:
			lock_rotation = true
			gravity_scale = _base_gravity_scale * POST_FIRST_STOP_GRAVITY_MULTIPLIER
			DiceMotionState.stop_motion(self)
		return

	if not _has_completed_first_stop:
		_has_completed_first_stop = true
		gravity_scale = _base_gravity_scale * POST_FIRST_STOP_GRAVITY_MULTIPLIER

	_align_top_face_to_camera()
	lock_rotation = true
	DiceMotionState.stop_motion(self)
	_physics_runtime.disable_bounce(self)
	_log_roll_result()


func _try_return_to_board_if_outside() -> void:
	if _is_returning_to_board:
		return
	if _slot_snap_controller != null and _slot_snap_controller.has_assigned_slot():
		return
	if not _has_completed_first_stop:
		return

	var board := _find_board_controller()
	if board == null:
		return
	if board.is_position_over_floor(global_position):
		return

	await get_tree().create_timer(0.75).timeout
	if _slot_snap_controller != null and _slot_snap_controller.has_assigned_slot():
		return

	_is_returning_to_board = true
	await _animate_return_to_board(board)
	_is_returning_to_board = false


func _align_top_face_to_camera() -> void:
	var active_camera := _resolve_alignment_camera()
	if active_camera == null:
		return
	_orientation_service.align_top_face_to_camera_bottom(self, FACE_NORMALS, active_camera)
	call_deferred("_align_top_face_to_camera_deferred")


func _align_top_face_to_camera_deferred() -> void:
	var active_camera := _resolve_alignment_camera()
	if active_camera == null:
		return
	_orientation_service.align_top_face_to_camera_bottom(self, FACE_NORMALS, active_camera)


func _resolve_alignment_camera() -> Camera3D:
	if not is_inside_tree():
		return null

	var viewport := get_viewport()
	if viewport == null:
		return null

	var viewport_camera := viewport.get_camera_3d()
	if viewport_camera != null:
		return viewport_camera

	var tree := get_tree()
	if tree == null:
		return null

	var scene_root := tree.current_scene
	if scene_root == null:
		return null

	for candidate in scene_root.find_children("*", "Camera3D", true, false):
		var camera := candidate as Camera3D
		if camera != null and camera.current:
			return camera
	return null


func _animate_return_to_board(board: BoardController) -> void:
	var saved_gravity_scale := DiceMotionState.begin_kinematic_control(self, true, false, 0.0)
	var start_position := global_position
	var lifted_position := start_position + Vector3.UP
	var target_position := board.get_random_floor_position() + Vector3.UP
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position", lifted_position, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_position, 0.35).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	await tween.finished
	DiceMotionState.restore_dynamic_control(self, saved_gravity_scale, true, true)


func _find_board_controller() -> BoardController:
	var node := get_parent()
	while node != null:
		if node is BoardController:
			return node as BoardController
		node = node.get_parent()
	return null


func _log_roll_result() -> void:
	if not OS.is_debug_build():
		return
	var top_value := get_top_face_value()
	var owner := StringName(get_meta(&"owner", &""))
	var owner_label := "неизвестно"
	if owner == &"player":
		owner_label = "юнит"
	elif owner == &"monster":
		owner_label = "монстр#%d" % (int(get_meta(&"monster_index", -1)) + 1)
	print("[Dice] выпал куб: %s значение=%d node=%s" % [owner_label, top_value, name])
