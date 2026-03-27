extends RefCounted
class_name GlobalMapMarkerPresenter

const PICK_RADIUS := 55.0
const UNAVAILABLE_MARK_TEXTURE := preload("res://assets/global_map/Х_mark.png")
const UNAVAILABLE_MARK_SCALE_MULTIPLIER := 1.3
const UNAVAILABLE_MARK_OFFSET_Y := 0.001

var _owner: Node3D
var _template_icon: MeshInstance3D
var _camera: Camera3D
var _markers: Array[Dictionary] = []
var _hovered_marker: MeshInstance3D


func configure(owner: Node3D, template_icon: MeshInstance3D, camera: Camera3D) -> void:
	_owner = owner
	_template_icon = template_icon
	_camera = camera


func clear_dynamic_markers() -> void:
	for marker_data in _markers:
		var node := marker_data.get("node") as Node3D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_markers.clear()
	_hovered_marker = null


func show_markers(marker_specs: Array[Dictionary], clear_existing: bool = true) -> void:
	if clear_existing:
		clear_dynamic_markers()
	if _owner == null or _template_icon == null:
		return
	for marker_spec in marker_specs:
		var node := _build_marker_node(marker_spec)
		if node == null:
			continue
		_owner.add_child(node)
		_markers.append({
			"node": node,
			"material": node.material_override,
			"base_color": (node.material_override as StandardMaterial3D).albedo_color if node.material_override is StandardMaterial3D else Color.WHITE,
			"scene_path": marker_spec.get("scene_path", ""),
			"type": marker_spec.get("type", ""),
			"icon": marker_spec.get("icon", null),
			"visible": marker_spec.get("visible", true),
			"unavailable": marker_spec.get("unavailable", false),
			"unavailable_mark": null,
		})
		node.visible = bool(marker_spec.get("visible", true))
		_set_marker_unavailable(node, bool(marker_spec.get("unavailable", false)))


func export_markers_state() -> Array[Dictionary]:
	var serialized_markers: Array[Dictionary] = []
	for marker_data in _markers:
		var marker_node := marker_data.get("node") as Node3D
		if marker_node == null or not is_instance_valid(marker_node):
			continue
		serialized_markers.append({
			"position": marker_node.global_position,
			"scene_path": marker_data.get("scene_path", ""),
			"type": marker_data.get("type", ""),
			"icon": marker_data.get("icon", null),
			"visible": marker_node.visible,
			"unavailable": marker_data.get("unavailable", false),
		})
	return serialized_markers


func pick_marker(mouse_position: Vector2) -> Dictionary:
	if _camera == null:
		return {}
	for marker_data in _markers:
		var marker_node := marker_data.get("node") as Node3D
		if marker_node == null or not marker_node.visible:
			continue
		if bool(marker_data.get("unavailable", false)):
			continue
		var projected := _camera.unproject_position(marker_node.global_position)
		if projected.distance_to(mouse_position) <= PICK_RADIUS:
			return marker_data
	return {}


func mark_all_markers_unavailable() -> void:
	for marker_data in _markers:
		var marker_node := marker_data.get("node") as MeshInstance3D
		if marker_node == null or not is_instance_valid(marker_node):
			continue
		_set_marker_unavailable(marker_node, true)


func set_hovered_marker(mouse_position: Vector2) -> void:
	var hovered_data := pick_marker(mouse_position)
	var marker_to_hover := hovered_data.get("node") as MeshInstance3D
	if marker_to_hover == _hovered_marker:
		return
	if _hovered_marker != null and is_instance_valid(_hovered_marker):
		_set_highlight(_hovered_marker, false)
	_hovered_marker = marker_to_hover
	if _hovered_marker != null and is_instance_valid(_hovered_marker):
		_set_highlight(_hovered_marker, true)


func clear_hovered_marker() -> void:
	if _hovered_marker != null and is_instance_valid(_hovered_marker):
		_set_highlight(_hovered_marker, false)
	_hovered_marker = null


func _build_marker_node(marker_spec: Dictionary) -> MeshInstance3D:
	if _template_icon == null:
		return null
	var marker := _template_icon.duplicate() as MeshInstance3D
	if marker == null:
		return null
	marker.global_position = marker_spec.get("position", _template_icon.global_position)
	marker.visible = true
	var material := _build_marker_material(marker_spec.get("icon") as Texture2D)
	if material != null:
		marker.material_override = material
	return marker


func _build_marker_material(icon: Texture2D) -> StandardMaterial3D:
	if icon == null:
		return null
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = icon
	return material


func _set_highlight(marker: MeshInstance3D, is_hovered: bool) -> void:
	if marker == null:
		return
	for marker_data in _markers:
		if marker_data.get("node") != marker:
			continue
		if bool(marker_data.get("unavailable", false)) and is_hovered:
			return
		var material := marker_data.get("material") as StandardMaterial3D
		if material == null:
			return
		var base_color := marker_data.get("base_color", Color.WHITE) as Color
		material.albedo_color = Color(0.7, 0.7, 0.7, 1.0) if is_hovered else base_color
		material.emission_enabled = is_hovered
		material.emission = Color(1.0, 1.0, 1.0, 1.0)
		material.emission_energy_multiplier = 0.03 if is_hovered else 0.0
		return


func _set_marker_unavailable(marker: MeshInstance3D, is_unavailable: bool) -> void:
	for marker_data in _markers:
		if marker_data.get("node") != marker:
			continue
		marker_data["unavailable"] = is_unavailable
		var unavailable_mark := marker_data.get("unavailable_mark") as MeshInstance3D
		if is_unavailable:
			if unavailable_mark == null or not is_instance_valid(unavailable_mark):
				unavailable_mark = _create_unavailable_mark(marker)
				if unavailable_mark != null:
					marker.add_child(unavailable_mark)
				marker_data["unavailable_mark"] = unavailable_mark
			if unavailable_mark != null:
				unavailable_mark.visible = true
			_set_highlight(marker, false)
		elif unavailable_mark != null and is_instance_valid(unavailable_mark):
			unavailable_mark.visible = false
		return


func _create_unavailable_mark(marker: MeshInstance3D) -> MeshInstance3D:
	if marker == null or marker.mesh == null:
		return null
	var unavailable_mark := MeshInstance3D.new()
	unavailable_mark.mesh = marker.mesh
	unavailable_mark.position = Vector3(0.0, UNAVAILABLE_MARK_OFFSET_Y, 0.0)
	unavailable_mark.scale = Vector3.ONE * UNAVAILABLE_MARK_SCALE_MULTIPLIER
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = UNAVAILABLE_MARK_TEXTURE
	unavailable_mark.material_override = material
	return unavailable_mark
