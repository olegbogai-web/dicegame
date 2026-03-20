@tool
extends Node3D
class_name DiceFaceDisplay3D

const FACE_ROTATIONS := [
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.0, PI, 0.0),
	Vector3(0.0, -PI * 0.5, 0.0),
	Vector3(0.0, PI * 0.5, 0.0),
	Vector3(-PI * 0.5, 0.0, 0.0),
	Vector3(PI * 0.5, 0.0, 0.0),
]

const FACE_NORMALS := [
	Vector3(0.0, 0.0, 1.0),
	Vector3(0.0, 0.0, -1.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(0.0, -1.0, 0.0),
]

var _label: Label3D
var _icon: Sprite3D
var _icon_library := DiceIconLibrary.new()

func _ready() -> void:
	_ensure_nodes()

func configure(face_index: int, face_data: DiceFaceData, cube_size: float) -> void:
	_ensure_nodes()

	position = FACE_NORMALS[face_index] * (cube_size * 0.5 + 0.011)
	rotation = FACE_ROTATIONS[face_index]
	_scale_content(face_data.overlay_scale * cube_size)

	_label.visible = face_data.is_number()
	_icon.visible = face_data.is_icon()

	if face_data.is_number():
		_label.text = face_data.get_display_text()
		_label.modulate = face_data.overlay_color
		return

	_label.text = ""
	_icon.texture = _icon_library.build_icon_texture(face_data.icon_id, face_data.overlay_color)

func _ensure_nodes() -> void:
	if _label == null:
		_label = Label3D.new()
		_label.name = "Number"
		_label.font_size = 96
		_label.pixel_size = 0.008
		_label.outline_size = 18
		_label.modulate = Color.WHITE
		_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		if Engine.is_editor_hint():
			_label.owner = get_tree().edited_scene_root

	if _icon == null:
		_icon = Sprite3D.new()
		_icon.name = "Icon"
		_icon.pixel_size = 0.0036
		_icon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_icon.alpha_cut = BaseMaterial3D.ALPHA_CUT_DISCARD
		_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(_icon)
		if Engine.is_editor_hint():
			_icon.owner = get_tree().edited_scene_root

func _scale_content(scale_value: float) -> void:
	_label.position = Vector3.ZERO
	_label.scale = Vector3.ONE * scale_value
	_icon.position = Vector3.ZERO
	_icon.scale = Vector3.ONE * scale_value
