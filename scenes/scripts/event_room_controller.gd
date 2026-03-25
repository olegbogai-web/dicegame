extends Node3D
class_name EventRoomController

const BoardController = preload("res://ui/scripts/board_controller.gd")
const Dice = preload("res://content/dice/dice.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const DiceDefinitionScript = preload("res://content/dice/resources/dice_definition.gd")
const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")
const DiceMotionState = preload("res://content/dice/runtime/dice_motion_state.gd")
const EventOutcomeDefinitionScript = preload("res://content/events/resources/event_outcome_definition.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")

const EVENT_DICE_SIZE_MULTIPLIER := Vector3(5.0, 5.0, 5.0)
const COLLAPSE_DURATION := 0.3
const STOP_CHECK_INTERVAL := 0.1
const EVENT_DICE_MASS := 2.0
const EVENT_DICE_TIMEOUT := 8.0
const CHOICE_HOVER_MODULATE := Color(1.15, 1.15, 0.95, 1.0)
const POSITIVE_FACE_ICON := preload("res://assets/material/green.png")
const NEUTRAL_FACE_ICON := preload("res://assets/material/yelow.png")
const NEGATIVE_FACE_ICON := preload("res://assets/material/red.png")

@export var event_definition: EventDefinition

@onready var _camera: Camera3D = $camera_event
@onready var _event_text: Label3D = $text_event
@onready var _background: MeshInstance3D = $background
@onready var _board: BoardController = $board
@onready var _choices_root: Node3D = $choices

var _choice_entries: Array[Dictionary] = []
var _selected_choice: EventChoiceDefinition
var _result_anchor_transform := Transform3D.IDENTITY
var _event_dice: Dice
var _is_resolving := false


func _ready() -> void:
	if event_definition == null:
		push_warning("EventDefinition is not assigned for EventRoomController.")
		return
	if not event_definition.is_valid_definition():
		push_warning("Assigned EventDefinition is invalid: %s" % event_definition.event_id)
		return

	if _camera != null:
		_camera.current = true
	_collect_choice_entries()
	_apply_event_definition()


func _collect_choice_entries() -> void:
	_choice_entries.clear()
	if _choices_root == null:
		return
	for choice_background in _choices_root.get_children():
		if not choice_background is MeshInstance3D:
			continue
		var label := choice_background.get_node_or_null(^"text_choice") as Label3D
		if label == null:
			continue
		var choice_body := choice_background.get_node_or_null(^"choice_body") as StaticBody3D
		_choice_entries.append({
			"background": choice_background,
			"choice_body": choice_body,
			"label": label,
			"base_modulate": choice_background.modulate,
			"base_scale": choice_background.scale,
			"base_label_scale": label.scale,
			"choice": null,
		})


func _apply_event_definition() -> void:
	_event_text.text = event_definition.event_text
	_result_anchor_transform = _event_text.transform
	_apply_background_texture(event_definition.background_texture)
	_apply_choices(event_definition.choices)


func _apply_background_texture(texture: Texture2D) -> void:
	if _background == null:
		return
	var material := _background.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("background", texture)


func _apply_choices(choices: Array[EventChoiceDefinition]) -> void:
	for index in _choice_entries.size():
		var entry := _choice_entries[index]
		var background := entry.get("background") as MeshInstance3D
		var label := entry.get("label") as Label3D
		if background == null or label == null:
			continue
		if index >= choices.size():
			background.visible = false
			entry["choice"] = null
			_choice_entries[index] = entry
			continue
		var choice := choices[index]
		background.visible = choice != null
		label.visible = choice != null
		if choice == null:
			continue
		label.text = choice.choice_text
		entry["choice"] = choice
		_choice_entries[index] = entry


func _input(event: InputEvent) -> void:
	if _is_resolving:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_try_pick_choice(mouse_button.position)


func _try_pick_choice(mouse_position: Vector2) -> void:
	var entry := _pick_choice_entry(mouse_position)
	if entry.is_empty():
		return
	_on_choice_selected(entry.get("choice") as EventChoiceDefinition)


func _process(_delta: float) -> void:
	if _is_resolving:
		return
	var hovered_entry := _pick_choice_entry(get_viewport().get_mouse_position())
	for entry in _choice_entries:
		var background := entry.get("background") as MeshInstance3D
		if background == null:
			continue
		var base_modulate := entry.get("base_modulate", Color.WHITE) as Color
		background.modulate = CHOICE_HOVER_MODULATE if entry == hovered_entry else base_modulate


func _pick_choice_entry(mouse_position: Vector2) -> Dictionary:
	if _camera == null:
		return {}
	var space_state := get_world_3d().direct_space_state
	var ray_origin := _camera.project_ray_origin(mouse_position)
	var ray_direction := _camera.project_ray_normal(mouse_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 200.0)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider := hit.get("collider") as Node
	if collider == null:
		return {}
	for entry in _choice_entries:
		if entry.get("choice") == null:
			continue
		var choice_body := entry.get("choice_body") as StaticBody3D
		if collider == choice_body:
			return entry
	return {}


func _on_choice_selected(choice: EventChoiceDefinition) -> void:
	if choice == null:
		return
	_selected_choice = choice
	_is_resolving = true
	await _play_selection_collapse_animation()
	await _roll_and_resolve()
	_is_resolving = false


func _play_selection_collapse_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for entry in _choice_entries:
		var background := entry.get("background") as MeshInstance3D
		var label := entry.get("label") as Label3D
		if background == null or label == null or not background.visible:
			continue
		var target_bg_scale := background.scale
		target_bg_scale.x = 0.01
		var target_label_scale := label.scale
		target_label_scale.x = 0.01
		tween.tween_property(background, "scale", target_bg_scale, COLLAPSE_DURATION)
		tween.tween_property(label, "scale", target_label_scale, COLLAPSE_DURATION)

	var target_event_scale := _event_text.scale
	target_event_scale.x = 0.01
	tween.tween_property(_event_text, "scale", target_event_scale, COLLAPSE_DURATION)
	await tween.finished

	for entry in _choice_entries:
		var background := entry.get("background") as MeshInstance3D
		if background != null:
			background.modulate = entry.get("base_modulate", Color.WHITE)
			background.visible = false
	_event_text.visible = false


func _roll_and_resolve() -> void:
	_spawn_event_dice(_selected_choice)
	if _event_dice == null:
		return
	var resolved_kind := await _wait_for_roll_outcome(_selected_choice)
	if is_instance_valid(_event_dice):
		_event_dice.queue_free()
		_event_dice = null

	var outcome := _selected_choice.get_outcome_for_kind(resolved_kind)
	_show_result(outcome)


func _spawn_event_dice(choice: EventChoiceDefinition) -> void:
	if _board == null or choice == null:
		return
	var dice_definition := _build_dice_definition(choice)
	var request := DiceThrowRequestScript.create(BASE_DICE_SCENE)
	request.extra_size_multiplier = EVENT_DICE_SIZE_MULTIPLIER
	request.mass = EVENT_DICE_MASS
	request.metadata["owner"] = "event"
	request.metadata["definition"] = dice_definition
	var dice_nodes := _board.throw_dice([request])
	if dice_nodes.is_empty():
		return
	_event_dice = dice_nodes[0] as Dice


func _wait_for_roll_outcome(_choice: EventChoiceDefinition) -> EventOutcomeDefinitionScript.OutcomeKind:
	var elapsed := 0.0
	while elapsed < EVENT_DICE_TIMEOUT:
		await get_tree().create_timer(STOP_CHECK_INTERVAL).timeout
		elapsed += STOP_CHECK_INTERVAL
		if _event_dice == null or not is_instance_valid(_event_dice):
			break
		if DiceMotionState.is_fully_stopped(_event_dice):
			return _resolve_top_kind(_event_dice)
	if _event_dice != null and is_instance_valid(_event_dice):
		return _resolve_top_kind(_event_dice)
	return EventOutcomeDefinitionScript.OutcomeKind.NEUTRAL


func _resolve_top_kind(dice: Dice) -> EventOutcomeDefinitionScript.OutcomeKind:
	var top_face := dice.get_top_face()
	if top_face == null:
		return EventOutcomeDefinitionScript.OutcomeKind.NEUTRAL
	match top_face.text_value:
		"positive":
			return EventOutcomeDefinitionScript.OutcomeKind.POSITIVE
		"negative":
			return EventOutcomeDefinitionScript.OutcomeKind.NEGATIVE
		_:
			return EventOutcomeDefinitionScript.OutcomeKind.NEUTRAL


func _show_result(outcome: EventOutcomeDefinition) -> void:
	if outcome == null:
		return
	_event_text.visible = true
	_event_text.transform = _result_anchor_transform
	_event_text.text = outcome.result_text


func _build_dice_definition(choice: EventChoiceDefinition) -> DiceDefinition:
	var definition := DiceDefinitionScript.new()
	definition.dice_name = "event_dice_%s" % choice.choice_id
	definition.size_multiplier = Vector3(1.2, 1.2, 1.2)
	definition.base_color = Color(0.96, 0.96, 0.96, 1.0)
	definition.faces = _build_dice_faces(choice)
	return definition


func _build_dice_faces(choice: EventChoiceDefinition) -> Array[DiceFaceDefinition]:
	var faces: Array[DiceFaceDefinition] = []
	for kind in choice.build_face_pool():
		var face := DiceFaceDefinitionScript.new()
		face.text_value = _get_kind_text_value(kind)
		face.content_type = DiceFaceDefinitionScript.ContentType.ICON
		face.icon = _get_kind_icon(kind)
		face.overlay_tint = Color(1.0, 1.0, 1.0, 1.0)
		faces.append(face)
	while faces.size() < DiceDefinitionScript.FACE_COUNT:
		var neutral_face := DiceFaceDefinitionScript.new()
		neutral_face.text_value = "neutral"
		neutral_face.content_type = DiceFaceDefinitionScript.ContentType.ICON
		neutral_face.icon = NEUTRAL_FACE_ICON
		neutral_face.overlay_tint = Color(1.0, 1.0, 1.0, 1.0)
		faces.append(neutral_face)
	return faces


func _get_kind_text_value(kind: EventOutcomeDefinitionScript.OutcomeKind) -> String:
	match kind:
		EventOutcomeDefinitionScript.OutcomeKind.POSITIVE:
			return "positive"
		EventOutcomeDefinitionScript.OutcomeKind.NEGATIVE:
			return "negative"
		_:
			return "neutral"


func _get_kind_icon(kind: EventOutcomeDefinitionScript.OutcomeKind) -> Texture2D:
	match kind:
		EventOutcomeDefinitionScript.OutcomeKind.POSITIVE:
			return POSITIVE_FACE_ICON
		EventOutcomeDefinitionScript.OutcomeKind.NEGATIVE:
			return NEGATIVE_FACE_ICON
		_:
			return NEUTRAL_FACE_ICON
