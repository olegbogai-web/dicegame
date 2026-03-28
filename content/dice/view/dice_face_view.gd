@tool
extends Node3D
class_name DiceFaceView

var _aura_sprite: Sprite3D
var _icon_sprite: Sprite3D
var _label: Label3D


func _ready() -> void:
	_ensure_nodes()


func apply_face(face_definition: DiceFaceDefinition, face_size: Vector2) -> void:
	_ensure_nodes()

	if face_definition == null:
		visible = false
		return

	visible = true
	_label.visible = false
	_icon_sprite.visible = false
	_aura_sprite.visible = false

	var max_size = max(face_size.x, face_size.y)
	var min_size = min(face_size.x, face_size.y)
	var base_pixel_size = max_size / 320.0

	if face_definition.has_aura():
		_aura_sprite.texture = _build_aura_texture(face_definition.aura_color)
		_aura_sprite.modulate = face_definition.aura_color
		_aura_sprite.pixel_size = max(base_pixel_size * face_definition.aura_scale * 6.0, 0.0001)
		_aura_sprite.visible = true

	match face_definition.content_type:
		DiceFaceDefinition.ContentType.ICON:
			if face_definition.icon != null:
				_icon_sprite.texture = face_definition.icon
				_icon_sprite.modulate = face_definition.overlay_tint
				var icon_texture_size := face_definition.icon.get_size()
				var icon_max_dimension = max(icon_texture_size.x, icon_texture_size.y)
				var icon_target_size = min_size * 0.95
				_icon_sprite.pixel_size = max(icon_target_size / max(icon_max_dimension, 1.0), 0.0001)
				_icon_sprite.visible = true
		DiceFaceDefinition.ContentType.TEXT:
			_label.text = face_definition.text_value
			_label.modulate = face_definition.text_color
			_label.outline_size = maxi(face_definition.text_outline_size, 0)
			_label.outline_modulate = face_definition.text_outline_color
			_label.font_size = face_definition.font_size
			_label.pixel_size = max(min_size * 0.7 / max(face_definition.font_size, 1), 0.0001)
			_label.visible = true


func _ensure_nodes() -> void:
	if _aura_sprite == null:
		_aura_sprite = Sprite3D.new()
		_aura_sprite.name = "Aura"
		_aura_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_aura_sprite.no_depth_test = false
		_aura_sprite.position = Vector3.ZERO
		add_child(_aura_sprite)
		_aura_sprite.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null

	if _icon_sprite == null:
		_icon_sprite = Sprite3D.new()
		_icon_sprite.name = "Icon"
		_icon_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_icon_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		_icon_sprite.no_depth_test = false
		_icon_sprite.position = Vector3(0.0, 0.0, 0.0005)
		add_child(_icon_sprite)
		_icon_sprite.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null

	if _label == null:
		_label = Label3D.new()
		_label.name = "Label"
		_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_label.no_depth_test = false
		_label.position = Vector3(0.0, 0.0, 0.0005)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		_label.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else null


func _build_aura_texture(aura_color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(aura_color.r, aura_color.g, aura_color.b, 0.0),
		Color(aura_color.r, aura_color.g, aura_color.b, aura_color.a),
		Color(aura_color.r, aura_color.g, aura_color.b, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.width = 128
	texture.height = 128
	return texture
