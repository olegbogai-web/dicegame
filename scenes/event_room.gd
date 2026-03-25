extends Node3D

const Dice = preload("res://content/dice/dice.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")

@export var event_definition: EventDefinition
@export_file("*.tscn") var fallback_scene_path := "res://scenes/new_battle_table.tscn"

@onready var _background: MeshInstance3D = $background
@onready var _event_text: Label3D = $text_event
@onready var _result_text: Label3D = $text_result
@onready var _choice_container: Node3D = $choices
@onready var _choice_template: MeshInstance3D = $choices/choice_background
@onready var _board_ui: CanvasLayer = get_node_or_null(^"board/UI")

var _choice_entries: Array[Dictionary] = []
var _is_resolving := false
var _active_dice: Dice


func _ready() -> void:
	if event_definition == null:
		push_warning("Event definition is not assigned.")
		return
	if _board_ui != null:
		_board_ui.visible = false
	_apply_event_definition()


func _apply_event_definition() -> void:
	_result_text.visible = false
	_event_text.visible = true
	_event_text.text = event_definition.event_text
	_set_background_texture(event_definition.background_texture)
	_rebuild_choices(event_definition.choices)


func _set_background_texture(texture: Texture2D) -> void:
	if _background == null:
		return
	var material := _background.material_override as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("background", texture)


func _rebuild_choices(choices: Array[EventChoiceDefinition]) -> void:
	_choice_entries.clear()
	for child in _choice_container.get_children():
		if child != _choice_template:
			child.queue_free()

	_choice_template.visible = false
	if choices.is_empty():
		return

	var spacing := 0.62
	for index in choices.size():
		var choice := choices[index]
		if choice == null:
			continue
		var node := _choice_template.duplicate() as MeshInstance3D
		node.name = "choice_background_%d" % index
		node.visible = true
		var transform_copy := node.transform
		transform_copy.origin.z = _choice_template.transform.origin.z + float(index) * spacing
		node.transform = transform_copy
		_choice_container.add_child(node)

		var label := node.get_node_or_null(^"text_choice") as Label3D
		if label != null:
			label.text = choice.choice_text

		node.input_ray_pickable = true
		node.create_convex_collision()
		node.input_event.connect(_on_choice_input.bind(choice, node))
		_choice_entries.append({
			"choice": choice,
			"node": node,
			"label": label,
		})


func _on_choice_input(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, choice: EventChoiceDefinition, node: MeshInstance3D) -> void:
	if _is_resolving:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_resolve_choice(choice, node)


func _resolve_choice(choice: EventChoiceDefinition, _selected_node: MeshInstance3D) -> void:
	if _is_resolving:
		return
	_is_resolving = true
	await _collapse_presentation()
	var outcome := await _roll_event_dice(choice)
	_show_result(outcome)


func _collapse_presentation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_event_text, "scale:x", 0.05, 0.12)
	for entry in _choice_entries:
		var node := entry.get("node") as Node3D
		var label := entry.get("label") as Node3D
		if node != null:
			tween.tween_property(node, "scale:x", 0.05, 0.12)
		if label != null:
			tween.tween_property(label, "scale:x", 0.05, 0.12)
	await tween.finished


func _roll_event_dice(choice: EventChoiceDefinition) -> EventOutcomeDefinition:
	if choice == null or choice.dice_definition == null:
		return null

	var dice_instance := BASE_DICE_SCENE.instantiate()
	if not dice_instance is Dice:
		return null

	_active_dice = dice_instance as Dice
	_active_dice.definition = choice.dice_definition
	_active_dice.extra_size_multiplier = Vector3.ONE * 6.5
	add_child(_active_dice)
	_active_dice.global_position = Vector3(0.0, 5.2, 0.0)
	_active_dice.angular_velocity = Vector3(24.0, 32.0, -20.0)
	_active_dice.linear_velocity = Vector3(1.8, 0.4, -1.2)

	await _wait_until_dice_sleeping(_active_dice)
	var top_face := _active_dice.get_top_face()
	var outcome := choice.get_outcome_by_face(top_face.text_value if top_face != null else "")
	_active_dice.queue_free()
	_active_dice = null
	return outcome


func _wait_until_dice_sleeping(dice: Dice) -> void:
	while is_instance_valid(dice):
		if dice.sleeping and dice.has_completed_first_stop():
			return
		await get_tree().physics_frame


func _show_result(outcome: EventOutcomeDefinition) -> void:
	_event_text.visible = false
	for entry in _choice_entries:
		var node := entry.get("node") as MeshInstance3D
		if node != null:
			node.visible = false
	_result_text.visible = true
	_result_text.text = outcome.result_text if outcome != null else "Событие завершено"


func _unhandled_input(event: InputEvent) -> void:
	if not _is_resolving:
		return
	if event.is_action_pressed("ui_accept") and not fallback_scene_path.is_empty():
		get_tree().change_scene_to_file(fallback_scene_path)
