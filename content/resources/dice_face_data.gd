@tool
extends Resource
class_name DiceFaceData

@export_enum("Number", "Icon") var content_type: int = 0
@export_range(0, 999, 1, "or_greater") var number_value: int = 1
@export var icon_id: StringName = &"star"
@export var overlay_color: Color = Color(1.0, 0.96, 0.88, 1.0)
@export var overlay_scale: float = 0.7

func get_display_text() -> String:
	return str(number_value)

func is_number() -> bool:
	return content_type == 0

func is_icon() -> bool:
	return content_type == 1
