@tool
extends Resource
class_name DiceDefinition

const FACE_COUNT := 6

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	UNIQUE,
}

enum Scope {
	COMBAT,
	GLOBAL_MAP,
	REWARD,
	MONEY,
	EVENT,
	SYSTEM,
}

@export var dice_name := "dice"
@export var rarity: Rarity = Rarity.COMMON
@export var scope: Scope = Scope.COMBAT
@export var base_size: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var size_multiplier: Vector3 = Vector3.ONE
@export var base_color: Color = Color(0.98039216, 0.9254902, 0.85490197, 1.0)
@export var texture: Texture2D
@export_range(0.0, 1.0, 0.01) var roughness := 0.95
@export_range(0.0, 1.0, 0.01) var metallic := 0.0
@export var faces: Array[DiceFaceDefinition] = []


func get_resolved_size() -> Vector3:
	return Vector3(
		base_size.x * size_multiplier.x,
		base_size.y * size_multiplier.y,
		base_size.z * size_multiplier.z,
	)


func get_face(index: int) -> DiceFaceDefinition:
	if index < 0 or index >= faces.size():
		return null
	return faces[index]


func get_face_count() -> int:
	return min(faces.size(), FACE_COUNT)


func is_combat_dice() -> bool:
	return scope == Scope.COMBAT
