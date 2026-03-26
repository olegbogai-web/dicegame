extends RefCounted
class_name GlobalMapMarkerPresenter

const PICK_RADIUS := 55.0
const MARKER_SCALE_MULTIPLIER := 0.4
const CROSSED_MARK_Y_OFFSET := 0.02
const X_MARK_ICON := preload("res://assets/global_map/Х_mark.png")

var _owner: Node3D
var _template_icon: MeshInstance3D
var _camera: Camera3D
var _markers: Array[Dictionary] = []
var _cross_marks: Array[Node3D] = []
var _hovered_marker_index := -1


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
	_hovered_marker_index = -1


func clear_cross_marks() -> void:
	for cross_mark in _cross_marks:
		if cross_mark != null and is_instance_valid(cross_mark):
			cross_mark.queue_free()
	_cross_marks.clear()


func show_markers(marker_specs: Array[Dictionary]) -> void:
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
			"scene_path": marker_spec.get("scene_path", ""),
			"type": marker_spec.get("type", ""),
			"disabled": marker_spec.get("disabled", false),
			"base_color": (node.material_override as StandardMaterial3D).albedo_color,
		})


func pick_marker(mouse_position: Vector2) -> Dictionary:
	if _camera == null:
		return {}
	for marker_data in _markers:
		var marker_node := marker_data.get("node") as Node3D
		if marker_node == null or not marker_node.visible or marker_data.get("disabled", false):
			continue
		var projected := _camera.unproject_position(marker_node.global_position)
		if projected.distance_to(mouse_position) <= PICK_RADIUS:
			return marker_data
	return {}


func update_hover(mouse_position: Vector2) -> void:
	if _camera == null:
		return
	var hovered_index := -1
	for index in _markers.size():
		var marker_data := _markers[index]
		var marker_node := marker_data.get("node") as Node3D
		if marker_node == null or not marker_node.visible or marker_data.get("disabled", false):
			continue
		var projected := _camera.unproject_position(marker_node.global_position)
		if projected.distance_to(mouse_position) <= PICK_RADIUS:
			hovered_index = index
			break
	if hovered_index == _hovered_marker_index:
		return
	_apply_hover_state(_hovered_marker_index, false)
	_hovered_marker_index = hovered_index
	_apply_hover_state(_hovered_marker_index, true)


func disable_unselected_markers(selected_node: Node3D) -> Array[Vector3]:
	var crossed_positions: Array[Vector3] = []
	for index in _markers.size():
		var marker_data := _markers[index]
		var marker_node := marker_data.get("node") as MeshInstance3D
		if marker_node == null or not is_instance_valid(marker_node):
			continue
		if marker_node == selected_node:
			continue
		marker_data["disabled"] = true
		_markers[index] = marker_data
		crossed_positions.append(marker_node.global_position)
		_add_cross_mark(marker_node.global_position)
	_apply_hover_state(_hovered_marker_index, false)
	_hovered_marker_index = -1
	return crossed_positions


func add_cross_mark(position: Vector3) -> void:
	_add_cross_mark(position)


func show_cross_marks(positions: Array[Vector3]) -> void:
	clear_cross_marks()
	for position in positions:
		_add_cross_mark(position)


func _build_marker_node(marker_spec: Dictionary) -> MeshInstance3D:
	if _template_icon == null:
		return null
	var marker := MeshInstance3D.new()
	marker.mesh = _template_icon.mesh
	marker.transform = _template_icon.transform
	marker.scale = marker.scale * MARKER_SCALE_MULTIPLIER
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


func _apply_hover_state(marker_index: int, is_hovered: bool) -> void:
	if marker_index < 0 or marker_index >= _markers.size():
		return
	var marker_data := _markers[marker_index]
	var marker_node := marker_data.get("node") as MeshInstance3D
	if marker_node == null:
		return
	var material := marker_node.material_override as StandardMaterial3D
	if material == null:
		return
	var base_color := marker_data.get("base_color", Color.WHITE) as Color
	material.albedo_color = Color(0.7, 0.7, 0.7, 1.0) if is_hovered else base_color
	material.emission_enabled = is_hovered
	material.emission = Color(1.0, 1.0, 1.0, 1.0)
	material.emission_energy_multiplier = 0.03 if is_hovered else 0.0


func _add_cross_mark(position: Vector3) -> void:
	if _owner == null or _template_icon == null:
		return
	if X_MARK_ICON == null:
		return
	var cross_mark := MeshInstance3D.new()
	cross_mark.mesh = _template_icon.mesh
	cross_mark.transform = _template_icon.transform
	cross_mark.scale = cross_mark.scale * MARKER_SCALE_MULTIPLIER
	cross_mark.global_position = position + Vector3(0.0, CROSSED_MARK_Y_OFFSET, 0.0)
	cross_mark.material_override = _build_marker_material(X_MARK_ICON)
	_owner.add_child(cross_mark)
	_cross_marks.append(cross_mark)
