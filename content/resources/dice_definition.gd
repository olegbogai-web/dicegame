@tool
extends Resource
class_name DiceDefinition

const DEFAULT_FACE_COUNT := 6

var _faces: Array[DiceFaceData] = []

@export_range(0.2, 4.0, 0.05, "or_greater") var cube_size: float = 1.0
@export var base_texture: Texture2D
@export var faces: Array[DiceFaceData]:
	get:
		return _faces
	set(value):
		_faces = value if value != null else []
		_ensure_face_count()

@export_range(0.1, 20.0, 0.1, "or_greater") var mass_value: float = 1.0
@export_range(0.0, 1.0, 0.01) var bounce: float = 0.15
@export_range(0.0, 1.0, 0.01) var friction: float = 0.8

func _init() -> void:
	_ensure_face_count()

func _ensure_face_count() -> void:
	while _faces.size() < DEFAULT_FACE_COUNT:
		var face := DiceFaceData.new()
		face.number_value = _faces.size() + 1
		_faces.append(face)

	if _faces.size() > DEFAULT_FACE_COUNT:
		_faces = _faces.slice(0, DEFAULT_FACE_COUNT)

func get_face(face_index: int) -> DiceFaceData:
	if face_index < 0 or face_index >= _faces.size():
		return null
	return _faces[face_index]
