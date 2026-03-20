extends Resource
class_name DiceDefinition

@export var display_name: String = "Common Die"
@export_range(0.2, 3.0, 0.05) var cube_size: float = 1.0
@export_range(0.1, 20.0, 0.1) var mass: float = 1.0
@export var base_texture: Texture2D
@export var face_contents: Array[DieFaceContent] = []

func get_face_content(face_index: int) -> DieFaceContent:
	if face_contents.is_empty():
		return null
	return face_contents[face_index % face_contents.size()]
