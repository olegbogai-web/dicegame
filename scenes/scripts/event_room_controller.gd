extends Node3D

const BoardController = preload("res://ui/scripts/board_controller.gd")
const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const EventOutcomeDefinition = preload("res://content/events/resources/event_outcome_definition.gd")

const CHOICE_VERTICAL_SPACING := -0.95
const COLLAPSE_DURATION := 0.5
const EVENT_DICE_SIZE := Vector3(6.0, 6.0, 6.0)

@export var event_definition: EventDefinition = preload("res://content/events/definitions/test_event_definition.tres")

@onready var _background: MeshInstance3D = $background
@onready var _text_event: Label3D = $text_event
@onready var _choice_template: MeshInstance3D = $choice_background
@onready var _board: BoardController = $board

var _choice_nodes: Array[Dictionary] = []
var _locked := false
var _event_die: Dice


func _ready() -> void:
	if _board != null:
		var board_ui := _board.get_node_or_null(^"UI") as CanvasLayer
		if board_ui != null:
			board_ui.visible = false
	_build_event_view()


func _build_event_view() -> void:
	if event_definition == null or not event_definition.is_valid_definition():
		_text_event.text = "Событие невалидно"
		_choice_template.visible = false
		return

	_apply_background_texture(event_definition.background_texture)
	_text_event.text = event_definition.event_text
	_render_choices(event_definition.choices)


func _render_choices(choices: Array[EventChoiceDefinition]) -> void:
	_clear_generated_choices()
	if choices.is_empty():
		_choice_template.visible = false
		return

	var base_transform := _choice_template.transform
	for index in choices.size():
		var choice := choices[index]
		if choice == null:
			continue
		var choice_node := _choice_template if index == 0 else _choice_template.duplicate()
		if index > 0:
			add_child(choice_node)
		choice_node.visible = true
		choice_node.name = "choice_background_%d" % index
		choice_node.transform = Transform3D(
			choice_node.transform.basis,
			base_transform.origin + Vector3(0.0, 0.0, CHOICE_VERTICAL_SPACING * float(index))
		)

		var choice_label := choice_node.get_node_or_null(^"text_choice") as Label3D
		if choice_label != null:
			choice_label.text = choice.choice_text

		var choice_area := _build_choice_area(choice_node)
		choice_area.input_event.connect(_on_choice_input_event.bind(index))
		_choice_nodes.append({
			"choice": choice,
			"background": choice_node,
			"label": choice_label,
			"area": choice_area,
		})


func _build_choice_area(choice_node: MeshInstance3D) -> Area3D:
	var area := Area3D.new()
	area.input_ray_pickable = true
	choice_node.add_child(area)

	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = BoxShape3D.new()
	(collision_shape.shape as BoxShape3D).size = Vector3(2.0, 0.5, 2.0)
	area.add_child(collision_shape)
	return area


func _on_choice_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, choice_index: int) -> void:
	if _locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_choice(choice_index)


func _select_choice(choice_index: int) -> void:
	if _locked:
		return
	if choice_index < 0 or choice_index >= _choice_nodes.size():
		return
	_locked = true

	var choice_data := _choice_nodes[choice_index]
	var choice := choice_data.get("choice") as EventChoiceDefinition
	if choice == null:
		return

	await _play_collapse_animation()
	await _roll_event_dice(choice)


func _play_collapse_animation() -> void:
	var tween := create_tween()
	for choice_data in _choice_nodes:
		var background := choice_data.get("background") as MeshInstance3D
		var label := choice_data.get("label") as Label3D
		if background != null:
			tween.parallel().tween_property(background, "scale:x", 0.01, COLLAPSE_DURATION)
		if label != null:
			tween.parallel().tween_property(label, "scale:x", 0.01, COLLAPSE_DURATION)
	tween.parallel().tween_property(_text_event, "scale:x", 0.01, COLLAPSE_DURATION)
	await tween.finished

	for choice_data in _choice_nodes:
		var background := choice_data.get("background") as MeshInstance3D
		if background != null:
			background.visible = false
	_text_event.visible = false


func _roll_event_dice(choice: EventChoiceDefinition) -> void:
	if _board == null:
		return
	var request := DiceThrowRequestScript.create(
		BASE_DICE_SCENE,
		Vector3.ZERO,
		1.5,
		EVENT_DICE_SIZE,
		{
			"owner": "event",
			"definition": _build_choice_dice_definition(choice),
		}
	)
	var dice_result := _board.throw_dice([request])
	if dice_result.is_empty() or not dice_result[0] is Dice:
		_text_event.visible = true
		_text_event.text = "Не удалось бросить куб события"
		return

	_event_die = dice_result[0] as Dice
	while is_instance_valid(_event_die) and not BattleAbilityRuntime.is_die_fully_stopped(_event_die):
		await get_tree().physics_frame

	if not is_instance_valid(_event_die):
		return

	var top_face := _event_die.get_top_face()
	var outcome_color := _resolve_outcome_color(top_face.text_value if top_face != null else "")
	var outcome := _resolve_outcome(choice, outcome_color)
	_event_die.queue_free()
	_event_die = null

	_text_event.visible = true
	_text_event.scale = Vector3.ONE
	_text_event.text = outcome.outcome_text if outcome != null else "Исход не найден"


func _build_choice_dice_definition(choice: EventChoiceDefinition) -> DiceDefinition:
	var definition := DiceDefinition.new()
	definition.dice_name = "event_choice_%s" % choice.choice_id
	definition.base_size = Vector3(0.2, 0.2, 0.2)
	definition.base_color = Color(0.99, 0.94, 0.82, 1.0)
	definition.faces = []

	for _green_index in choice.green_faces:
		definition.faces.append(_build_face("green", Color(0.25, 0.95, 0.35, 1.0)))
	for _yellow_index in choice.yellow_faces:
		definition.faces.append(_build_face("yellow", Color(1.0, 0.92, 0.3, 1.0)))
	for _red_index in choice.red_faces:
		definition.faces.append(_build_face("red", Color(1.0, 0.35, 0.35, 1.0)))
	while definition.faces.size() < DiceDefinition.FACE_COUNT:
		definition.faces.append(_build_face("yellow", Color(1.0, 0.92, 0.3, 1.0)))
	if definition.faces.size() > DiceDefinition.FACE_COUNT:
		definition.faces = definition.faces.slice(0, DiceDefinition.FACE_COUNT)
	return definition


func _build_face(face_value: String, tint_color: Color) -> DiceFaceDefinition:
	var face := DiceFaceDefinition.new()
	face.text_value = face_value
	face.text_color = tint_color
	face.overlay_tint = tint_color
	face.font_size = 54
	return face


func _resolve_outcome_color(top_face_value: String) -> EventOutcomeDefinition.OutcomeColor:
	match top_face_value:
		"green":
			return EventOutcomeDefinition.OutcomeColor.GREEN
		"red":
			return EventOutcomeDefinition.OutcomeColor.RED
		_:
			return EventOutcomeDefinition.OutcomeColor.YELLOW


func _resolve_outcome(choice: EventChoiceDefinition, outcome_color: EventOutcomeDefinition.OutcomeColor) -> EventOutcomeDefinition:
	match outcome_color:
		EventOutcomeDefinition.OutcomeColor.GREEN:
			return choice.positive_outcome
		EventOutcomeDefinition.OutcomeColor.RED:
			return choice.negative_outcome
		_:
			return choice.neutral_outcome


func _clear_generated_choices() -> void:
	for choice_data in _choice_nodes:
		var background := choice_data.get("background") as MeshInstance3D
		if background != null and background != _choice_template:
			background.queue_free()
	_choice_nodes.clear()


func _apply_background_texture(texture: Texture2D) -> void:
	if _background == null or texture == null:
		return
	var material := _background.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("background", texture)
