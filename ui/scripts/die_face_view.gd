extends Node3D
class_name DieFaceView

const FACE_RESOLUTION := Vector2i(256, 256)
const LABEL_SETTINGS := preload("res://ui/scenes/dice/face_label_settings.tres")

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var _viewport: SubViewport = $SubViewport
@onready var _base_rect: TextureRect = $SubViewport/FaceRoot/BaseTexture
@onready var _overlay_rect: TextureRect = $SubViewport/FaceRoot/Overlay/Icon
@onready var _label: Label = $SubViewport/FaceRoot/Overlay/Label
@onready var _background: ColorRect = $SubViewport/FaceRoot/Background

func configure(face_content: DieFaceContent, base_texture: Texture2D, face_size: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * face_size
	_mesh_instance.mesh = quad

	var material := StandardMaterial3D.new()
	material.albedo_texture = _viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance.material_override = material

	_viewport.size = FACE_RESOLUTION
	_base_rect.texture = base_texture
	_label.label_settings = LABEL_SETTINGS
	_apply_content(face_content)

func _apply_content(face_content: DieFaceContent) -> void:
	_overlay_rect.visible = false
	_label.visible = false

	if face_content == null:
		_background.color = Color(1, 1, 1, 0)
		_label.visible = true
		_label.text = "?"
		return


	_background.color = face_content.background_modulate

	if face_content.is_icon():
		var icon_texture := _resolve_icon(face_content)
		if icon_texture != null:
			_overlay_rect.visible = true
			_overlay_rect.texture = icon_texture
			_overlay_rect.modulate = face_content.icon_modulate
			return

	_label.visible = true
	_label.text = face_content.text
	_label.modulate = face_content.text_color

func _resolve_icon(face_content: DieFaceContent) -> Texture2D:
	var theme := ThemeDB.get_default_theme()
	if theme == null:
		return null
	if theme.has_icon(face_content.icon_name, face_content.icon_theme_type):
		return theme.get_icon(face_content.icon_name, face_content.icon_theme_type)
	return null
