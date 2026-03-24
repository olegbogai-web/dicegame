extends Node3D

const Dice = preload("res://content/dice/dice.gd")
const DiceDefinitionScript = preload("res://content/dice/resources/dice_definition.gd")
const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")
const BattleAbilityRuntime = preload("res://content/combat/runtime/battle_ability_runtime.gd")
const BASE_DICE_SCENE = preload("res://content/resources/base_cube.tscn")
const EventDefinitionScript = preload("res://content/events/resources/event_definition.gd")
const EventChoiceDefinitionScript = preload("res://content/events/resources/event_choice_definition.gd")

const FACE_GREEN := &"green"
const FACE_YELLOW := &"yellow"
const FACE_RED := &"red"
const COLLAPSED_SCALE_X := 0.01
const EVENT_DICE_DISTANCE := 34.0

@export var event_definition: EventDefinition = preload("res://content/events/definitions/test_event_definition.tres")

@onready var _camera: Camera3D = $camera_event
@onready var _event_label: Label3D = $text_event
@onready var _background: MeshInstance3D = $background
@onready var _choice_template: MeshInstance3D = $choice_background

var _choice_states: Array[Dictionary] = []
var _roll_in_progress := false
var _result_label: Label3D


func _ready() -> void:
	if event_definition == null or not event_definition.is_valid_event():
		push_error("Event room requires a valid event definition.")
		return
	_apply_event_view()
	_build_choice_views()


func _apply_event_view() -> void:
	_event_label.text = event_definition.event_text
	_result_label = _event_label.duplicate() as Label3D
	_result_label.name = "result_event"
	_result_label.visible = false
	add_child(_result_label)

	var shader_material := _background.material_override as ShaderMaterial
	if shader_material != null:
		shader_material = shader_material.duplicate() as ShaderMaterial
		shader_material.set_shader_parameter("background", event_definition.background)
		_background.material_override = shader_material


func _build_choice_views() -> void:
	_choice_states.clear()
	var choices := event_definition.choices
	if choices.is_empty():
		_choice_template.visible = false
		return

	var spacing := 0.85
	var start_offset := -0.5 * spacing * float(choices.size() - 1)
	for index in choices.size():
		var choice := choices[index]
		if choice == null:
			continue
		var background := _choice_template if index == 0 else _choice_template.duplicate() as MeshInstance3D
		if index > 0:
			add_child(background)
		background.visible = true
		background.name = "choice_background_%d" % index
		var origin := _choice_template.transform.origin
		origin.z = _choice_template.transform.origin.z + start_offset + spacing * float(index)
		background.transform = Transform3D(background.transform.basis, origin)
		var label := background.get_node_or_null(^"text_choice") as Label3D
		if label != null:
			label.text = choice.choice_text
			label.width = 470.0
		_choice_states.append({
			"choice": choice,
			"background": background,
			"label": label,
		})


func _unhandled_input(event: InputEvent) -> void:
	if _roll_in_progress:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var mouse_event := event as InputEventMouseButton
	var chosen_state := _find_choice_at_point(mouse_event.position)
	if chosen_state.is_empty():
		return

	get_viewport().set_input_as_handled()
	await _resolve_choice(chosen_state)


func _find_choice_at_point(screen_point: Vector2) -> Dictionary:
	for index in range(_choice_states.size() - 1, -1, -1):
		var state := _choice_states[index]
		var mesh := state.get("background") as MeshInstance3D
		if _screen_point_hits_mesh(mesh, screen_point):
			return state
	return {}


func _resolve_choice(choice_state: Dictionary) -> void:
	_roll_in_progress = true
	await _collapse_before_roll()

	var chosen := choice_state.get("choice") as EventChoiceDefinition
	var event_dice := _spawn_event_dice(chosen)
	if event_dice == null:
		_roll_in_progress = false
		return

	await _wait_for_die_stop(event_dice)
	var result_text := _resolve_result_text(chosen, event_dice)
	event_dice.queue_free()

	_result_label.text = result_text
	_result_label.visible = true
	_roll_in_progress = false


func _collapse_before_roll() -> void:
	for choice_state in _choice_states:
		var background := choice_state.get("background") as MeshInstance3D
		var label := choice_state.get("label") as Label3D
		if background != null:
			background.scale.x = COLLAPSED_SCALE_X
		if label != null:
			label.scale.x = COLLAPSED_SCALE_X
	_event_label.scale.x = COLLAPSED_SCALE_X
	await get_tree().process_frame


func _spawn_event_dice(choice: EventChoiceDefinition) -> Dice:
	if choice == null:
		return null
	var dice_node := BASE_DICE_SCENE.instantiate() as Dice
	if dice_node == null:
		return null

	dice_node.definition = _build_event_dice_definition(choice)
	dice_node.extra_size_multiplier = Vector3.ONE * 2.3
	add_child(dice_node)

	var center_screen := get_viewport().get_visible_rect().size * 0.5
	var spawn_point := _camera.project_position(center_screen, EVENT_DICE_DISTANCE)
	dice_node.global_position = spawn_point + Vector3.UP * 1.8
	dice_node.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	dice_node.linear_velocity = Vector3(randf_range(-5.0, 5.0), randf_range(4.0, 8.0), randf_range(-5.0, 5.0))
	dice_node.angular_velocity = Vector3(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	return dice_node


func _wait_for_die_stop(dice_node: Dice) -> void:
	while is_instance_valid(dice_node):
		if dice_node.has_completed_first_stop() and BattleAbilityRuntime.is_die_fully_stopped(dice_node):
			break
		await get_tree().create_timer(0.1).timeout


func _resolve_result_text(choice: EventChoiceDefinition, dice_node: Dice) -> String:
	if choice == null or dice_node == null:
		return ""
	var top_face := dice_node.get_top_face()
	if top_face == null:
		return choice.neutral_text

	match StringName(top_face.text_value.to_lower()):
		FACE_GREEN:
			return choice.positive_text
		FACE_YELLOW:
			return choice.neutral_text
		FACE_RED:
			return choice.negative_text
		_:
			return choice.neutral_text


func _build_event_dice_definition(choice: EventChoiceDefinition) -> DiceDefinition:
	var definition := DiceDefinitionScript.new()
	definition.dice_name = "event_dice"
	definition.size_multiplier = Vector3.ONE * 2.4
	definition.base_color = Color(0.13, 0.14, 0.18, 1.0)
	definition.roughness = 0.3
	definition.metallic = 0.1

	var faces: Array[DiceFaceDefinition] = []
	for _index in choice.green_faces:
		faces.append(_build_face(FACE_GREEN, Color(0.21, 0.88, 0.45, 1.0)))
	for _index in choice.yellow_faces:
		faces.append(_build_face(FACE_YELLOW, Color(1.0, 0.89, 0.26, 1.0)))
	for _index in choice.red_faces:
		faces.append(_build_face(FACE_RED, Color(1.0, 0.31, 0.31, 1.0)))
	while faces.size() < 6:
		faces.append(_build_face(FACE_YELLOW, Color(1.0, 0.89, 0.26, 1.0)))
	if faces.size() > 6:
		faces = faces.slice(0, 6)
	definition.faces = faces
	return definition


func _build_face(text_value: StringName, tint: Color) -> DiceFaceDefinition:
	var face := DiceFaceDefinitionScript.new()
	face.content_type = DiceFaceDefinition.ContentType.TEXT
	face.text_value = String(text_value)
	face.text_color = Color.WHITE
	face.overlay_tint = tint
	face.font_size = 34
	face.aura_color = Color(tint.r, tint.g, tint.b, 0.35)
	face.aura_scale = 0.22
	return face


func _screen_point_hits_mesh(mesh_instance: MeshInstance3D, screen_point: Vector2) -> bool:
	if mesh_instance == null or not is_instance_valid(mesh_instance) or not mesh_instance.visible:
		return false
	if mesh_instance.mesh == null:
		return false
	var projected_rect := _project_mesh_screen_rect(mesh_instance)
	return projected_rect.size.x > 0.0 and projected_rect.size.y > 0.0 and projected_rect.has_point(screen_point)


func _project_mesh_screen_rect(mesh_instance: MeshInstance3D) -> Rect2:
	var aabb := mesh_instance.mesh.get_aabb()
	var corners := [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for corner in corners:
		var projected := _camera.unproject_position(mesh_instance.to_global(corner))
		min_point.x = minf(min_point.x, projected.x)
		min_point.y = minf(min_point.y, projected.y)
		max_point.x = maxf(max_point.x, projected.x)
		max_point.y = maxf(max_point.y, projected.y)
	if not min_point.is_finite() or not max_point.is_finite():
		return Rect2()
	return Rect2(min_point, max_point - min_point)
