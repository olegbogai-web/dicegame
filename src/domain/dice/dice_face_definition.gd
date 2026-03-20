extends Resource
class_name DiceFaceDefinition

enum FaceContentType {
	TEXT,
	ICON,
}

@export var content_type: FaceContentType = FaceContentType.TEXT
@export_multiline var text: String = ""
@export var icon_id: StringName
@export var background_color: Color = Color(1, 1, 1, 0.82)
@export var foreground_color: Color = Color(0.15, 0.09, 0.05, 1)
