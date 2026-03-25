extends Node3D

const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")
const Dice = preload("res://content/dice/dice.gd")

@export var event_definition: EventDefinition = preload("res://content/events/definitions/test_event/test_event_definition.tres")
@export var collapse_duration := 0.08
@export var collapsed_scale_x := 0.01
@export var event_dice_size_multiplier: Vector3 = Vector3(3.5, 3.5, 3.5)
@export var return_scene_path := "res://scenes/new_battle_table.tscn"

@onready var _camera: Camera3D = $camera_event
@onready var _board: BoardController = $board
@onready var _background: MeshInstance3D = $background
@onready var _event_text: Label3D = $text_event
@onready var _result_text: Label3D = $text_event_result
@onready var _choice_nodes: Array[Node3D] = [
	$choice_slot_1,
	$choice_slot_2,
	$choice_slot_3,
]
@onready var _back_button: Button = $UI/BackButton

var _choice_to_slot: Dictionary = {}
var _slot_to_choice: Dictionary = {}
var _selected_choice: EventChoiceDefinition
var _active_dice: Dice
var _is_waiting_choice := false
var _is_waiting_dice_result := false


func _ready() -> void:
	set_physics_process(true)
	_configure_board_ui()
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_button_pressed):
		_back_button.pressed.connect(_on_back_button_pressed)
	_apply_event_definition()


func _physics_process(_delta: float) -> void:
	if not _is_waiting_dice_result:
		return
	if _active_dice == null or not is_instance_valid(_active_dice):
		return
	if not DiceMotionState.is_fully_stopped(_active_dice):
		return
	_resolve_event_result()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_waiting_choice:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var from := _camera.project_ray_origin(mouse_event.position)
	var to := from + _camera.project_ray_normal(mouse_event.position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider := result.get("collider")
	if collider == null or not _choice_to_slot.has(collider):
		return

	var slot := _choice_to_slot[collider] as Node3D
	var choice := _slot_to_choice.get(slot) as EventChoiceDefinition
	if choice == null:
		return

	_on_choice_selected(choice)


func _apply_event_definition() -> void:
	if event_definition == null or not event_definition.is_valid_event():
		push_warning("EventRoom: invalid event definition.")
		return

	_apply_background_texture(event_definition.background_texture)
	_event_text.text = event_definition.event_text
	_result_text.visible = false
	_result_text.text = ""
	_bind_choices(event_definition.choices)
	_is_waiting_choice = true


func _apply_background_texture(texture: Texture2D) -> void:
	if _background == null or texture == null:
		return
	var shader_material := _background.material_override as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("background", texture)


func _bind_choices(choices: Array[EventChoiceDefinition]) -> void:
	_choice_to_slot.clear()
	_slot_to_choice.clear()

	for index in _choice_nodes.size():
		var slot := _choice_nodes[index]
		if slot == null:
			continue
		var has_choice := index < choices.size() and choices[index] != null
		slot.visible = has_choice
		if not has_choice:
			continue

		var choice := choices[index]
		var text_label := slot.get_node_or_null(^"choice_background/text_choice") as Label3D
		if text_label != null:
			text_label.text = choice.choice_text

		var hit_area := slot.get_node_or_null(^"choice_hit_area") as Area3D
		if hit_area != null:
			_choice_to_slot[hit_area] = slot
		_slot_to_choice[slot] = choice


func _on_choice_selected(choice: EventChoiceDefinition) -> void:
	if _is_waiting_dice_result:
		return
	_selected_choice = choice
	_is_waiting_choice = false
	_collapse_event_ui()
	_throw_event_dice()


func _collapse_event_ui() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(_event_text, "scale:x", collapsed_scale_x, collapse_duration)
	for slot in _choice_nodes:
		if slot == null or not slot.visible:
			continue
		var choice_background := slot.get_node_or_null(^"choice_background") as Node3D
		if choice_background != null:
			tween.tween_property(choice_background, "scale:x", collapsed_scale_x, collapse_duration)
		var choice_text := slot.get_node_or_null(^"choice_background/text_choice") as Node3D
		if choice_text != null:
			tween.tween_property(choice_text, "scale:x", collapsed_scale_x, collapse_duration)


func _throw_event_dice() -> void:
	if _board == null or _selected_choice == null or _selected_choice.event_dice_definition == null:
		push_warning("EventRoom: cannot throw dice without board or choice dice definition.")
		return

	var request := DiceThrowRequestScript.create(_board.default_dice_scene)
	request.extra_size_multiplier = event_dice_size_multiplier
	request.metadata = {
		"definition": _selected_choice.event_dice_definition,
	}

	var spawned := _board.throw_dice([request])
	if spawned.is_empty() or not (spawned[0] is Dice):
		push_warning("EventRoom: failed to spawn event dice.")
		return

	_active_dice = spawned[0] as Dice
	_is_waiting_dice_result = true


func _resolve_event_result() -> void:
	_is_waiting_dice_result = false
	if _active_dice == null or not is_instance_valid(_active_dice):
		return

	var top_face := _active_dice.get_top_face()
	var color_key := "yellow"
	if top_face != null and not top_face.text_value.is_empty():
		color_key = top_face.text_value.to_lower()

	var outcome := _selected_choice.get_outcome_for_color(color_key)
	if outcome == null:
		outcome = _selected_choice.neutral_outcome

	_active_dice.queue_free()
	_active_dice = null
	_show_result_text(outcome.outcome_text)


func _show_result_text(text: String) -> void:
	_result_text.text = text
	_result_text.visible = true


func _configure_board_ui() -> void:
	if _board == null:
		return
	var board_ui := _board.get_node_or_null(^"UI") as CanvasLayer
	if board_ui != null:
		board_ui.visible = false


func _on_back_button_pressed() -> void:
	if return_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(return_scene_path)
