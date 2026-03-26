extends RefCounted
class_name GlobalMapEventIconPresenter

var _event_icon: Node3D
var _material: StandardMaterial3D
var _base_color := Color.WHITE


func configure(event_icon: Node3D) -> void:
	_event_icon = event_icon
	if not _event_icon is MeshInstance3D:
		return
	var mesh_icon := _event_icon as MeshInstance3D
	var source_material := mesh_icon.material_override as StandardMaterial3D
	if source_material == null:
		return
	_material = source_material.duplicate() as StandardMaterial3D
	mesh_icon.material_override = _material
	_base_color = _material.albedo_color
	_set_highlight(false)


func hide() -> void:
	if _event_icon == null:
		return
	_event_icon.visible = false


func set_hovered(is_hovered: bool) -> void:
	_set_highlight(is_hovered)


func _set_highlight(is_hovered: bool) -> void:
	if _material == null:
		return
	_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0) if is_hovered else _base_color
	_material.emission_enabled = is_hovered
	_material.emission = Color(1.0, 1.0, 1.0, 1.0)
	_material.emission_energy_multiplier = 0.35 if is_hovered else 0.0
