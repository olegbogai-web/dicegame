@tool
class_name DiceDefinition
extends Resource

const DEFAULT_SIZE := Vector3(0.2, 0.2, 0.2)

@export var id: StringName = &"base_cube"
@export var display_name: String = "Base Cube"
@export var base_size: Vector3 = DEFAULT_SIZE
@export var size_multiplier: float = 1.0
@export var cube_color: Color = Color(0.995, 0.855, 0.837, 1.0)
@export var surface_texture: Texture2D
@export_range(0.0, 0.05, 0.001) var face_padding: float = 0.004
@export_range(0.05, 1.0, 0.01) var face_scale: float = 0.72
@export var faces: Array[DiceFaceData] = []

func get_scaled_size() -> Vector3:
	return Vector3(
		max(base_size.x * size_multiplier, 0.001),
		max(base_size.y * size_multiplier, 0.001),
		max(base_size.z * size_multiplier, 0.001)
	)
