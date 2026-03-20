extends Node3D
class_name DiceFaceView

const VIEWPORT_SIZE := Vector2i(256, 256)
const PANEL_PADDING := 18.0

var _definition: DiceFaceDefinition
var _icon_library: DiceIconLibrary
var _face_size: Vector2 = Vector2.ONE

@export var definition: DiceFaceDefinition:
	get:
		return _definition
	set(value):
		_definition = value
		_refresh_view()

@export var icon_library: DiceIconLibrary:
	get:
		return _icon_library
	set(value):
		_icon_library = value
		_refresh_view()

@export var size: Vector2 = Vector2.ONE:
	get:
		return _face_size
	set(value):
		_face_size = value
		_refresh_mesh()

var _mesh_instance: MeshInstance3D
var _viewport: SubViewport
var _root_control: Control
var _background_rect: ColorRect
var _label: Label
var _icon_rect: TextureRect

func _ready() -> void:
	_ensure_nodes()
	_refresh_mesh()
	_refresh_view()

func _ensure_nodes() -> void:
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Overlay"
		add_child(_mesh_instance)

	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "FaceViewport"
		_viewport.disable_3d = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_viewport.transparent_bg = true
		_viewport.size = VIEWPORT_SIZE
		add_child(_viewport)

	if _root_control == null:
		_root_control = Control.new()
		_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		_viewport.add_child(_root_control)

		_background_rect = ColorRect.new()
		_background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root_control.add_child(_background_rect)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", int(PANEL_PADDING))
		margin.add_theme_constant_override("margin_top", int(PANEL_PADDING))
		margin.add_theme_constant_override("margin_right", int(PANEL_PADDING))
		margin.add_theme_constant_override("margin_bottom", int(PANEL_PADDING))
		_root_control.add_child(margin)

		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_child(center)

		var content := Control.new()
		content.custom_minimum_size = Vector2(180, 180)
		center.add_child(content)

		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.add_theme_font_size_override("font_size", 108)
		content.add_child(_label)

		_icon_rect = TextureRect.new()
		_icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(_icon_rect)

func _refresh_mesh() -> void:
	if not is_node_ready():
		return

	_ensure_nodes()

	var quad := QuadMesh.new()
	quad.size = _face_size
	_mesh_instance.mesh = quad

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = _viewport.get_texture()
	_mesh_instance.material_override = material

func _refresh_view() -> void:
	if not is_node_ready():
		return

	_ensure_nodes()

	var face_definition := _definition
	if face_definition == null:
		_background_rect.color = Color(1, 1, 1, 0)
		_label.visible = false
		_icon_rect.visible = false
		return

	_background_rect.color = face_definition.background_color
	_label.modulate = face_definition.foreground_color
	_icon_rect.modulate = face_definition.foreground_color

	if face_definition.content_type == DiceFaceDefinition.FaceContentType.ICON:
		_icon_rect.texture = _resolve_icon(face_definition.icon_id)
		_icon_rect.visible = _icon_rect.texture != null
		_label.visible = false
	else:
		_label.text = face_definition.text
		_label.visible = true
		_icon_rect.visible = false

func _resolve_icon(icon_id: StringName) -> Texture2D:
	if _icon_library != null:
		var icon := _icon_library.get_icon(icon_id)
		if icon != null:
			return icon

	var theme := ThemeDB.get_default_theme()
	if theme == null or icon_id.is_empty():
		return null

	for theme_type in ["EditorIcons", "Icons", "Button", "Label", "Tree"]:
		if theme.has_icon(icon_id, theme_type):
			return theme.get_icon(icon_id, theme_type)

	return null
