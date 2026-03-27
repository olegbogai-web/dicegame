extends RefCounted
class_name GlobalMapMarkerPresenter

const PICK_RADIUS := 55.0

var _owner: Node3D
var _template_icon: MeshInstance3D
var _camera: Camera3D
var _markers: Array[Dictionary] = []


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
		})


func pick_marker(mouse_position: Vector2) -> Dictionary:
	if _camera == null:
		return {}
	for marker_data in _markers:
		var marker_node := marker_data.get("node") as Node3D
		if marker_node == null or not marker_node.visible:
			continue
		var projected := _camera.unproject_position(marker_node.global_position)
		if projected.distance_to(mouse_position) <= PICK_RADIUS:
			return marker_data
	return {}


func _build_marker_node(marker_spec: Dictionary) -> MeshInstance3D:
	if _template_icon == null:
		return null
	var marker := MeshInstance3D.new()
	marker.mesh = _template_icon.mesh
	marker.transform = _template_icon.transform
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
