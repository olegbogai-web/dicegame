extends RefCounted
class_name BattleTargetingService

const Dice = preload("res://content/dice/dice.gd")

const ACTIVATION_TARGET_LIFT_Y := 0.8
const SELECTED_FRAME_LIFT_Y := 1.9


func resolve_target_descriptor_at_screen_point(
	ability: AbilityDefinition,
	screen_point: Vector2,
	battle_room_data: BattleRoom,
	player_sprite: MeshInstance3D,
	monster_sprite_states: Array[Dictionary],
	floor_mesh: MeshInstance3D,
	camera: Camera3D
) -> Dictionary:
	if battle_room_data == null or ability == null or ability.target_rule == null:
		return {}

	match ability.target_rule.get_target_hint():
		&"self":
			if screen_point_hits_mesh(player_sprite, screen_point, camera) and battle_room_data.can_target_player():
				return {
					"kind": &"player",
				}
		&"single_enemy":
			for index in range(monster_sprite_states.size() - 1, -1, -1):
				var monster_state = monster_sprite_states[index]
				var sprite := monster_state.get("sprite") as MeshInstance3D
				var monster_index := int(monster_state.get("index", -1))
				if screen_point_hits_mesh(sprite, screen_point, camera) and battle_room_data.can_target_monster(monster_index):
					return {
						"kind": &"monster",
						"index": monster_index,
					}
		&"all_enemies":
			for monster_state in monster_sprite_states:
				var sprite := monster_state.get("sprite") as MeshInstance3D
				if screen_point_hits_mesh(sprite, screen_point, camera):
					return {
						"kind": &"all_monsters",
					}
			if screen_point_hits_mesh(floor_mesh, screen_point, camera):
				return {
					"kind": &"all_monsters",
				}
		&"global":
			return {
				"kind": &"all_monsters",
			}
	return {}


func resolve_activation_target_origin(
	target_descriptor: Dictionary,
	base_origin: Vector3,
	battle_room_data: BattleRoom,
	player_sprite: MeshInstance3D,
	monster_sprite_states: Array[Dictionary]
) -> Vector3:
	var target_kind := StringName(target_descriptor.get("kind", &""))
	if target_kind == &"player":
		return player_sprite.global_position + Vector3.UP * ACTIVATION_TARGET_LIFT_Y
	if target_kind == &"monster":
		var monster_index := int(target_descriptor.get("index", -1))
		for monster_state in monster_sprite_states:
			if int(monster_state.get("index", -1)) == monster_index:
				var sprite := monster_state.get("sprite") as MeshInstance3D
				return sprite.global_position + Vector3.UP * ACTIVATION_TARGET_LIFT_Y
	if target_kind == &"all_monsters":
		var living_monster_positions: Array[Vector3] = []
		for monster_state in monster_sprite_states:
			var monster_index := int(monster_state.get("index", -1))
			if battle_room_data == null or not battle_room_data.can_target_monster(monster_index):
				continue
			var sprite := monster_state.get("sprite") as MeshInstance3D
			living_monster_positions.append(sprite.global_position)
		if not living_monster_positions.is_empty():
			var center := Vector3.ZERO
			for position in living_monster_positions:
				center += position
			center /= float(living_monster_positions.size())
			return center + Vector3.UP * ACTIVATION_TARGET_LIFT_Y
	return base_origin + Vector3.UP * SELECTED_FRAME_LIFT_Y


func project_mouse_to_horizontal_plane(camera: Camera3D, viewport: Viewport, plane_y: float) -> Vector3:
	var mouse_position = viewport.get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_direction = camera.project_ray_normal(mouse_position)
	var denominator = ray_direction.y
	if absf(denominator) < 0.0001:
		return Vector3(ray_origin.x, plane_y, ray_origin.z)
	var distance = (plane_y - ray_origin.y) / denominator
	if distance < 0.0:
		distance = 0.0
	var hit_position = ray_origin + ray_direction * distance
	hit_position.y = plane_y
	return hit_position


func screen_point_hits_mesh(mesh_instance: MeshInstance3D, screen_point: Vector2, camera: Camera3D) -> bool:
	if mesh_instance == null or not is_instance_valid(mesh_instance) or not mesh_instance.visible:
		return false
	if mesh_instance.mesh == null:
		return false
	var projected_rect := project_mesh_screen_rect(mesh_instance, camera)
	return projected_rect.size.x > 0.0 and projected_rect.size.y > 0.0 and projected_rect.has_point(screen_point)


func has_player_dice_at_screen_point(screen_point: Vector2, camera: Camera3D, world_3d: World3D) -> bool:
	if camera == null or world_3d == null:
		return false
	var ray_query := PhysicsRayQueryParameters3D.create(
		camera.project_ray_origin(screen_point),
		camera.project_ray_origin(screen_point) + camera.project_ray_normal(screen_point) * 1000.0
	)
	var hit = world_3d.direct_space_state.intersect_ray(ray_query)
	if hit.is_empty():
		return false
	var collider := hit.get("collider") as Node
	return collider is Dice and StringName(collider.get_meta(&"owner", &"")) == &"player"


func project_mesh_screen_rect(mesh_instance: MeshInstance3D, camera: Camera3D) -> Rect2:
	var aabb := mesh_instance.mesh.get_aabb()
	var corners := [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
		Vector3(aabb.position.x + aabb.size.x, aabb.position.y + aabb.size.y, aabb.position.z + aabb.size.z),
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for corner in corners:
		var projected = camera.unproject_position(mesh_instance.to_global(corner))
		min_point.x = minf(min_point.x, projected.x)
		min_point.y = minf(min_point.y, projected.y)
		max_point.x = maxf(max_point.x, projected.x)
		max_point.y = maxf(max_point.y, projected.y)
	return Rect2(min_point, max_point - min_point)
