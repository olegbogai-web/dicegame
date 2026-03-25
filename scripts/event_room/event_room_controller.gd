extends Node3D

const EventChoiceResolver = preload("res://content/events/runtime/event_choice_resolver.gd")
const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const EventChoiceViewScene = preload("res://scenes/event_room/event_choice_view.tscn")
const EventDefinition = preload("res://content/events/resources/event_definition.gd")
const EventChoiceDefinition = preload("res://content/events/resources/event_choice_definition.gd")
const Dice = preload("res://content/dice/dice.gd")

const COLLAPSE_X := 0.03
const COLLAPSE_DURATION := 0.08

@export var event_definition: EventDefinition

@onready var _text_event: Label3D = $text_event
@onready var _background: MeshInstance3D = $background
@onready var _choices_anchor: Node3D = $choices_anchor
@onready var _board: BoardController = $board

var _rng := RandomNumberGenerator.new()
var _choice_views: Array[EventChoiceView] = []
var _choice_by_view: Dictionary = {}
var _selected_choice: EventChoiceDefinition
var _is_resolving := false


func _ready() -> void:
	_rng.randomize()
	if event_definition == null:
		event_definition = load("res://content/events/definitions/test_event/test_event_definition.tres") as EventDefinition
	_bind_event()


func _bind_event() -> void:
	if event_definition == null:
		return
	_text_event.text = event_definition.event_text
	_apply_background_texture(event_definition.background_texture)
	_build_choice_views(event_definition.choices)


func _apply_background_texture(texture: Texture2D) -> void:
	if _background == null or texture == null:
		return
	var material := _background.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("background", texture)


func _build_choice_views(choices: Array[EventChoiceDefinition]) -> void:
	for view in _choice_views:
		if is_instance_valid(view):
			view.queue_free()
	_choice_views.clear()
	_choice_by_view.clear()

	var spacing := 1.15
	var offset := (float(choices.size() - 1) * spacing) * 0.5
	for index in choices.size():
		var choice := choices[index]
		if choice == null:
			continue
		var view := EventChoiceViewScene.instantiate() as EventChoiceView
		view.name = "choice_%s" % choice.choice_id
		view.transform.origin = Vector3(-5.45, 0.563, 1.5 + float(index) * spacing - offset)
		view.set_choice_text(choice.choice_text)
		view.selected.connect(_on_choice_selected)
		_choices_anchor.add_child(view)
		_choice_views.append(view)
		_choice_by_view[view] = choice


func _on_choice_selected(view: EventChoiceView) -> void:
	if _is_resolving:
		return
	if not _choice_by_view.has(view):
		return
	_is_resolving = true
	_selected_choice = _choice_by_view[view] as EventChoiceDefinition
	for choice_view in _choice_views:
		choice_view.set_interaction_enabled(false)
	await _play_collapse_animation()
	var resolved_color := await _roll_event_dice(_selected_choice)
	var outcome := EventChoiceResolver.resolve_outcome(_selected_choice, resolved_color, _rng)
	_text_event.text = outcome.outcome_text if outcome != null else "Исход не определен"
	_is_resolving = false


func _play_collapse_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for view in _choice_views:
		tween.tween_method(func(value: float) -> void:
			if is_instance_valid(view):
				view.collapse_x(value)
		, 3.5, COLLAPSE_X, COLLAPSE_DURATION)
	tween.tween_method(func(value: float) -> void:
		var basis := _text_event.transform.basis
		basis.x = basis.x.normalized() * value
		_text_event.transform = Transform3D(basis, _text_event.transform.origin)
	, 3.354, COLLAPSE_X, COLLAPSE_DURATION)
	await tween.finished


func _roll_event_dice(choice: EventChoiceDefinition) -> StringName:
	if _board == null or choice == null or choice.event_dice_definition == null:
		return &"yellow"
	var request := DiceThrowRequestScript.create(_board.default_dice_scene)
	request.metadata["definition"] = choice.event_dice_definition
	var dice_nodes := _board.throw_dice([request])
	if dice_nodes.is_empty():
		return &"yellow"
	var dice := dice_nodes[0] as Dice
	if dice == null:
		return &"yellow"
	while is_instance_valid(dice) and (not dice.sleeping or not dice.has_completed_first_stop()):
		await get_tree().physics_frame
	var color_tag := _resolve_color_from_face(dice)
	if is_instance_valid(dice):
		dice.queue_free()
	return color_tag


func _resolve_color_from_face(dice: Dice) -> StringName:
	if dice == null:
		return &"yellow"
	var top_face := dice.get_top_face()
	if top_face == null:
		return &"yellow"
	var value := top_face.text_value.to_lower()
	if value == "green":
		return &"green"
	if value == "red":
		return &"red"
	return &"yellow"
