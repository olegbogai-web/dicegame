extends Node3D

const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")

@export var event_definition: EventDefinition
@export var board_path: NodePath = ^"board"
@export var event_text_path: NodePath = ^"text_event"
@export var choice_template_path: NodePath = ^"choice_background"
@export var background_path: NodePath = ^"background"
@export_file("*.tscn") var fallback_scene_path := "res://scenes/new_battle_table.tscn"

@onready var _board: BoardController = get_node_or_null(board_path)
@onready var _event_text: Label3D = get_node_or_null(event_text_path)
@onready var _choice_template: MeshInstance3D = get_node_or_null(choice_template_path)
@onready var _background: MeshInstance3D = get_node_or_null(background_path)

var _choice_entries: Array[Dictionary] = []
var _active_dice: Dice
var _initial_event_text_scale := Vector3.ONE
var _initial_choice_scales: Array[Vector3] = []
var _state := "await_choice"


func _ready() -> void:
	if event_definition == null:
		push_warning("Event definition is not assigned for event_room.")
		return
	if _board != null:
		var board_ui := _board.get_node_or_null(^"UI") as CanvasLayer
		if board_ui != null:
			board_ui.visible = false
	if _event_text != null:
		_initial_event_text_scale = _event_text.scale
		_event_text.text = event_definition.event_text
	_apply_background_texture()
	_build_choice_views()


func _unhandled_input(event: InputEvent) -> void:
	if _state == "completed" and event.is_action_pressed("ui_accept"):
		_return_to_fallback_scene()
	if _state == "await_choice" and event is InputEventMouseButton:
		var mouse_button_event := event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT and mouse_button_event.pressed:
			_try_select_choice_from_mouse()


func _build_choice_views() -> void:
	if _choice_template == null:
		return
	_choice_entries.clear()
	_initial_choice_scales.clear()

	var choices := event_definition.choices
	if choices.is_empty():
		_choice_template.visible = false
		return

	var spacing := 0.8
	var start_offset := -0.5 * spacing * float(max(choices.size() - 1, 0))
	for index in choices.size():
		var choice := choices[index]
		if choice == null:
			continue

		var choice_node := _choice_template if index == 0 else _choice_template.duplicate() as MeshInstance3D
		if index > 0:
			choice_node.name = "choice_background_%d" % index
			_choice_template.get_parent().add_child(choice_node)
		var new_origin := choice_node.transform.origin
		new_origin.z = _choice_template.transform.origin.z + start_offset + float(index) * spacing
		choice_node.transform = Transform3D(choice_node.transform.basis, new_origin)
		choice_node.visible = true

		var text_choice := choice_node.get_node_or_null(^"text_choice") as Label3D
		if text_choice != null:
			text_choice.text = choice.choice_text

		_initial_choice_scales.append(choice_node.scale)
		_choice_entries.append({
			"choice": choice,
			"background": choice_node,
			"text": text_choice,
		})

	if not _choice_entries.is_empty():
		_choice_entries[0].get("background").input_ray_pickable = true
		for entry in _choice_entries:
			var background := entry.get("background") as MeshInstance3D
			if background != null:
				background.input_ray_pickable = true


func _try_select_choice_from_mouse() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_3d()
	if camera == null:
		return
	var mouse_pos := viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider := result.get("collider") as Node
	if collider == null:
		return
	for entry in _choice_entries:
		var background := entry.get("background") as MeshInstance3D
		if background == null:
			continue
		if collider == background or collider.is_ancestor_of(background) or background.is_ancestor_of(collider):
			_start_choice_resolution(entry.get("choice") as EventChoiceDefinition)
			return


func _start_choice_resolution(choice: EventChoiceDefinition) -> void:
	if choice == null or _state != "await_choice":
		return
	_state = "resolving"
	await _collapse_event_view()
	await _throw_and_wait_for_result(choice)


func _collapse_event_view() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	if _event_text != null:
		tween.tween_property(_event_text, "scale:x", 0.02, 0.1)
	for entry in _choice_entries:
		var background := entry.get("background") as Node3D
		var text_choice := entry.get("text") as Node3D
		if background != null:
			tween.tween_property(background, "scale:x", 0.02, 0.1)
		if text_choice != null:
			tween.tween_property(text_choice, "scale:x", 0.02, 0.1)
	await tween.finished


func _throw_and_wait_for_result(choice: EventChoiceDefinition) -> void:
	if _board == null or choice.dice_definition == null:
		_apply_outcome_text("Результат не определён.")
		return

	var request := DiceThrowRequestScript.create(_board.default_dice_scene)
	request.extra_size_multiplier = Vector3(3.0, 3.0, 3.0)
	request.metadata["definition"] = choice.dice_definition
	var dice_list := _board.throw_dice([request])
	if dice_list.is_empty() or not (dice_list[0] is Dice):
		_apply_outcome_text("Результат не определён.")
		return

	_active_dice = dice_list[0] as Dice
	await _await_dice_stop(_active_dice)
	var top_face := _active_dice.get_top_face()
	var color_id := "yellow"
	if top_face != null and not top_face.text_value.is_empty():
		color_id = top_face.text_value
	_active_dice.queue_free()
	_active_dice = null

	var outcome := choice.get_outcome_by_color(color_id)
	var result_text := outcome.result_text if outcome != null else "Результат не определён."
	_apply_outcome_text(result_text)


func _await_dice_stop(dice: Dice) -> void:
	if dice == null:
		return
	while is_instance_valid(dice):
		if dice.sleeping and dice.linear_velocity.length() < 0.05 and dice.angular_velocity.length() < 0.05:
			return
		await get_tree().physics_frame


func _apply_outcome_text(result_text: String) -> void:
	for entry in _choice_entries:
		var background := entry.get("background") as MeshInstance3D
		if background != null:
			background.visible = false
	if _event_text != null:
		_event_text.text = result_text
		_event_text.scale = _initial_event_text_scale
	_state = "completed"


func _apply_background_texture() -> void:
	if _background == null or event_definition.background_texture == null:
		return
	var material := _background.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("background", event_definition.background_texture)


func _return_to_fallback_scene() -> void:
	if fallback_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(fallback_scene_path)
