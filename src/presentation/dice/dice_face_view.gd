@tool
class_name DiceFaceView
extends Node3D

const TEXT_FONT_SIZE := 64
const AURA_SCALE := 1.14
const FACE_PLANE_DEPTH := 0.0005

var _front: Node3D
var _aura: Node3D

func _ready() -> void:
	if get_child_count() == 0:
		_build_nodes()

func setup(face_data: DiceFaceData, face_size: Vector2) -> void:
	if face_data == null:
		return
	if _front == null:
		_build_nodes()

	var has_aura := face_data.aura_strength > 0.0 and face_data.aura_color.a > 0.0
	_front.visible = true
	_aura.visible = has_aura
	_apply_content(_front, face_data, face_size, 1.0)
	if has_aura:
		_apply_content(_aura, face_data, face_size, AURA_SCALE + face_data.aura_strength * 0.2, face_data.aura_color)

func _build_nodes() -> void:
	_front = Node3D.new()
	_front.name = "Front"
	add_child(_front)
	_front.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	_aura = Node3D.new()
	_aura.name = "Aura"
	add_child(_aura)
	_aura.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
	_aura.position = Vector3(0, 0, -FACE_PLANE_DEPTH)

func _apply_content(target: Node3D, face_data: DiceFaceData, face_size: Vector2, content_scale: float, override_color: Color = Color.TRANSPARENT) -> void:
	for child in target.get_children():
		child.free()

	if face_data.use_icon and face_data.icon != null:
		var sprite := Sprite3D.new()
		sprite.texture = face_data.icon
		sprite.modulate = override_color if override_color != Color.TRANSPARENT else Color.WHITE
		sprite.pixel_size = max(face_size.x, face_size.y) * 0.006 / content_scale
		sprite.position = Vector3.ZERO
		target.add_child(sprite)
		sprite.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
		sprite.scale = Vector3.ONE * content_scale
		return

	var label := Label3D.new()
	label.text = face_data.label_text
	label.modulate = override_color if override_color != Color.TRANSPARENT else face_data.text_color
	label.font_size = TEXT_FONT_SIZE
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3.ZERO
	label.scale = Vector3.ONE * min(face_size.x, face_size.y) * 0.035 * content_scale
	target.add_child(label)
	label.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self
