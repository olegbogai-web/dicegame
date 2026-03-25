@tool
extends Resource
class_name DiceFaceDefinition

enum ContentType {
	TEXT,
	ICON,
	FACE_COLOR,
}

@export var content_type: ContentType = ContentType.TEXT
@export var text_value := "1"
@export var icon: Texture2D
@export var text_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var overlay_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var face_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(16, 256, 1) var font_size := 96
@export var aura_color: Color = Color(1.0, 1.0, 1.0, 0.0)
@export_range(0.0, 1.0, 0.01) var aura_scale := 0.32


func has_aura() -> bool:
	return aura_color.a > 0.0 and aura_scale > 0.0
