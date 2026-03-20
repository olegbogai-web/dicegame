extends Resource
class_name DiceDefinition

@export var id: StringName
@export var display_name: String = ""
@export var base_texture: Texture2D
@export var size: Vector3 = Vector3.ONE
@export_range(0.1, 0.95, 0.01) var overlay_fill: float = 0.72
@export var faces: Array[DiceFaceDefinition] = []

func get_face_definition(face_index: int) -> DiceFaceDefinition:
	if face_index < 0 or face_index >= faces.size():
		return null

	return faces[face_index]
