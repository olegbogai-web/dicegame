@tool
class_name DiceFaceData
extends Resource

@export var label_text: String = "1"
@export var icon: Texture2D
@export var use_icon: bool = false
@export var text_color: Color = Color.BLACK
@export var aura_color: Color = Color(0, 0, 0, 0)
@export_range(0.0, 2.0, 0.01) var aura_strength: float = 0.0
