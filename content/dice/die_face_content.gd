extends Resource
class_name DieFaceContent

@export_enum("text", "icon") var content_type: String = "text"
@export var text: String = "1"
@export var icon_name: StringName = &""
@export var icon_theme_type: StringName = &"CheckBox"
@export var icon_modulate: Color = Color(0.12, 0.09, 0.06, 1.0)
@export var text_color: Color = Color(0.12, 0.09, 0.06, 1.0)
@export var background_modulate: Color = Color(1, 1, 1, 0.0)

func is_icon() -> bool:
	return content_type == "icon" and not icon_name.is_empty()
