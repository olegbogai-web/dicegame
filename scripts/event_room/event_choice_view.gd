extends Node3D
class_name EventChoiceView

signal selected(view: EventChoiceView)

@onready var _collision_body: StaticBody3D = $StaticBody3D
@onready var _label: Label3D = $choice_background/text_choice
@onready var _background: MeshInstance3D = $choice_background


func _ready() -> void:
	if _collision_body != null and not _collision_body.input_event.is_connected(_on_input_event):
		_collision_body.input_event.connect(_on_input_event)


func set_choice_text(value: String) -> void:
	if _label != null:
		_label.text = value


func set_interaction_enabled(value: bool) -> void:
	if _collision_body != null:
		_collision_body.input_ray_pickable = value


func collapse_x(scale_x: float) -> void:
	if _background != null:
		var basis := _background.transform.basis
		basis.x = basis.x.normalized() * scale_x
		_background.transform = Transform3D(basis, _background.transform.origin)
	if _label != null:
		var label_basis := _label.transform.basis
		label_basis.x = label_basis.x.normalized() * max(scale_x, 0.01)
		_label.transform = Transform3D(label_basis, _label.transform.origin)


func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("selected", self)
