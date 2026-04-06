extends RefCounted
class_name RarityFrameVisuals

const BASE_FRAME_NORMAL := preload("res://assets/ui/base_frame_normal.png")
const BASE_FRAME_COPPER := preload("res://assets/ui/base_frame_copper_.png")
const BASE_FRAME_SILVER := preload("res://assets/ui/base_frame_silver.png")
const BASE_FRAME_GOLD := preload("res://assets/ui/base_frame_gold.png")


static func resolve_base_frame_by_rarity(rarity_value: Variant) -> Texture2D:
	if rarity_value is StringName:
		match rarity_value as StringName:
			&"uncommon":
				return BASE_FRAME_COPPER
			&"rare":
				return BASE_FRAME_SILVER
			&"unique":
				return BASE_FRAME_GOLD
		return BASE_FRAME_NORMAL
	if rarity_value is int:
		match int(rarity_value):
			1:
				return BASE_FRAME_COPPER
			2:
				return BASE_FRAME_SILVER
			3:
				return BASE_FRAME_GOLD
		return BASE_FRAME_NORMAL
	return BASE_FRAME_NORMAL


static func apply_base_frame_to_mesh_instance(mesh_instance: MeshInstance3D, rarity_value: Variant) -> void:
	if mesh_instance == null:
		return
	var target_texture := resolve_base_frame_by_rarity(rarity_value)
	if target_texture == null:
		return
	var material := mesh_instance.material_override
	if material == null:
		material = StandardMaterial3D.new()
	else:
		material = material.duplicate()
	if material is StandardMaterial3D:
		material.albedo_texture = target_texture
	mesh_instance.material_override = material
