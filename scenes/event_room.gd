extends Node3D

const BoardController = preload("res://ui/scripts/board_controller.gd")
const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const EventDefinition = preload("res://content/events/resources/event_definition.gd")
const EventChoiceDefinition = preload("res://content/events/resources/event_choice_definition.gd")
const EventOutcomeDefinition = preload("res://content/events/resources/event_outcome_definition.gd")
const EventData = preload("res://content/events/definitions/test_event.tres")
const BaseDiceScene = preload("res://content/resources/base_cube.tscn")
const DiceFaceDefinition = preload("res://content/dice/resources/dice_face_definition.gd")
const DiceDefinition = preload("res://content/dice/resources/dice_definition.gd")

const FULLSCREEN_DICE_SIZE := Vector3(4.0, 4.0, 4.0)
const COLLAPSE_SCALE_X := 0.03
const COLLAPSE_DURATION := 0.1

@onready var _camera: Camera3D = $camera_event
@onready var _event_label: Label3D = $text_event
@onready var _background: MeshInstance3D = $background
@onready var _choice_template: MeshInstance3D = $choice_background
@onready var _board: BoardController = $board

var _event_definition: EventDefinition
var _choice_nodes: Array[Dictionary] = []
var _selected_choice: EventChoiceDefinition
var _event_dice: Dice
var _is_resolving := false


func _ready() -> void:
	if _camera != null:
		_camera.current = true
	_hide_board_ui()
	_setup_event(EventData)


func _hide_board_ui() -> void:
	if _board == null:
		return
	var board_ui := _board.get_node_or_null(^"UI") as CanvasLayer
	if board_ui != null:
		board_ui.visible = false


func _setup_event(definition: EventDefinition) -> void:
	if definition == null or not definition.is_valid_event():
		push_warning("Event definition is invalid.")
		return
	_event_definition = definition
	_apply_background(definition.background_texture)
	_event_label.text = definition.event_text
	_build_choices(definition.choices)


func _apply_background(texture: Texture2D) -> void:
	if _background == null or texture == null:
		return
	var material := _background.material_override as ShaderMaterial
	if material == null:
		return
	material = material.duplicate()
	material.set_shader_parameter("background", texture)
	_background.material_override = material


func _build_choices(choices: Array[EventChoiceDefinition]) -> void:
	_clear_choices()
	if _choice_template == null:
		return
	var z_step := 1.25
	for index in choices.size():
		var choice := choices[index]
		if choice == null:
			continue
		var choice_node := _choice_template if index == 0 else _choice_template.duplicate() as MeshInstance3D
		if index > 0:
			choice_node.name = "choice_background_%d" % index
			add_child(choice_node)
		var origin := _choice_template.transform.origin
		origin.z += z_step * float(index)
		choice_node.transform = Transform3D(choice_node.transform.basis, origin)
		var label := choice_node.get_node_or_null(^"text_choice") as Label3D
		if label != null:
			label.text = choice.choice_text
		_ensure_choice_click_body(choice_node, index)
		_choice_nodes.append({
			"choice": choice,
			"background": choice_node,
			"label": label,
		})


func _ensure_choice_click_body(choice_node: MeshInstance3D, choice_index: int) -> void:
	var click_body := choice_node.get_node_or_null(^"choice_click") as StaticBody3D
	if click_body == null:
		click_body = StaticBody3D.new()
		click_body.name = "choice_click"
		choice_node.add_child(click_body)
		click_body.owner = get_tree().edited_scene_root

	var collision := click_body.get_node_or_null(^"collision") as CollisionShape3D
	if collision == null:
		collision = CollisionShape3D.new()
		collision.name = "collision"
		click_body.add_child(collision)
		collision.owner = get_tree().edited_scene_root
	if collision.shape == null:
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.8, 0.8, 1.0)
		collision.shape = shape

	if not click_body.input_event.is_connected(_on_choice_input_event):
		click_body.input_event.connect(_on_choice_input_event.bind(choice_index))


func _on_choice_input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int, choice_index: int) -> void:
	if _is_resolving:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_choice(choice_index)


func _select_choice(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= _choice_nodes.size():
		return
	_selected_choice = _choice_nodes[choice_index].get("choice") as EventChoiceDefinition
	if _selected_choice == null:
		return
	_is_resolving = true
	for choice_data in _choice_nodes:
		var body := (choice_data.get("background") as MeshInstance3D).get_node_or_null(^"choice_click") as StaticBody3D
		if body != null:
			body.process_mode = Node.PROCESS_MODE_DISABLED
	await _collapse_content()
	await _throw_event_dice_and_resolve()


func _collapse_content() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for choice_data in _choice_nodes:
		var choice_background := choice_data.get("background") as MeshInstance3D
		var choice_label := choice_data.get("label") as Label3D
		if choice_background != null:
			tween.tween_property(choice_background, "scale:x", COLLAPSE_SCALE_X, COLLAPSE_DURATION)
		if choice_label != null:
			tween.tween_property(choice_label, "scale:x", COLLAPSE_SCALE_X, COLLAPSE_DURATION)
	tween.tween_property(_event_label, "scale:x", COLLAPSE_SCALE_X, COLLAPSE_DURATION)
	await tween.finished


func _throw_event_dice_and_resolve() -> void:
	if _board == null or _selected_choice == null:
		return
	var dice_definition := _build_event_dice_definition(_selected_choice)
	if dice_definition == null:
		return
	var request := DiceThrowRequestScript.create(BaseDiceScene, Vector3.ZERO, 1.0, FULLSCREEN_DICE_SIZE, {
		"definition": dice_definition,
		"owner": &"event",
	})
	var dice_array := _board.throw_dice([request])
	if dice_array.is_empty():
		return
	_event_dice = dice_array[0] as Dice
	if _event_dice == null:
		return
	await _wait_for_die_to_stop(_event_dice)
	var outcome_text := _resolve_outcome_text(_event_dice, _selected_choice)
	_event_dice.queue_free()
	_show_outcome_text(outcome_text)


func _wait_for_die_to_stop(dice: Dice) -> void:
	if dice == null:
		return
	while is_instance_valid(dice) and not dice.sleeping:
		await get_tree().physics_frame


func _resolve_outcome_text(dice: Dice, choice: EventChoiceDefinition) -> String:
	if dice == null or choice == null:
		return ""
	var top_face := dice.get_top_face()
	if top_face == null:
		return ""
	var color := _classify_color(top_face.overlay_tint)
	match color:
		EventOutcomeDefinition.OutcomeColor.GREEN:
			return choice.green_outcome.text
		EventOutcomeDefinition.OutcomeColor.RED:
			return choice.red_outcome.text
		_:
			return choice.yellow_outcome.text


func _show_outcome_text(outcome_text: String) -> void:
	_event_label.text = outcome_text
	_event_label.scale = Vector3.ONE


func _classify_color(color: Color) -> EventOutcomeDefinition.OutcomeColor:
	if color.g > color.r and color.g > color.b:
		return EventOutcomeDefinition.OutcomeColor.GREEN
	if color.r > color.g and color.r > color.b:
		return EventOutcomeDefinition.OutcomeColor.RED
	return EventOutcomeDefinition.OutcomeColor.YELLOW


func _build_event_dice_definition(choice: EventChoiceDefinition) -> DiceDefinition:
	if choice == null:
		return null
	var face_colors: Array[Color] = []
	for _index in choice.green_faces:
		face_colors.append(Color(0.2, 0.9, 0.4, 1.0))
	for _index in choice.yellow_faces:
		face_colors.append(Color(1.0, 0.86, 0.25, 1.0))
	for _index in choice.red_faces:
		face_colors.append(Color(0.95, 0.22, 0.22, 1.0))
	if face_colors.size() < 6:
		for _index in 6 - face_colors.size():
			face_colors.append(Color(1.0, 0.86, 0.25, 1.0))

	face_colors.shuffle()

	var definition := DiceDefinition.new()
	definition.dice_name = "event_dice"
	definition.size_multiplier = Vector3(3.0, 3.0, 3.0)
	definition.base_color = Color(0.95, 0.95, 0.95, 1.0)

	var faces: Array[DiceFaceDefinition] = []
	for index in 6:
		var face := DiceFaceDefinition.new()
		face.text_value = str(index + 1)
		face.overlay_tint = face_colors[index]
		face.text_color = Color(0.05, 0.05, 0.05, 1.0)
		faces.append(face)
	definition.faces = faces
	return definition


func _clear_choices() -> void:
	for choice_data in _choice_nodes:
		var choice_background := choice_data.get("background") as MeshInstance3D
		if choice_background != null and choice_background != _choice_template:
			choice_background.queue_free()
	_choice_nodes.clear()
