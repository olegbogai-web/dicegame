extends RefCounted
class_name BattleSceneViewRenderer

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")
const RarityFrameVisuals = preload("res://content/combat/presentation/rarity_frame_visuals.gd")

const TINT_MATERIAL_META_KEY := &"runtime_tint_material"
const HEALTH_BAR_META_KEY := &"health_bar_base_transform"
const HEALTH_BAR_CURRENT_RATIO_META_KEY := &"health_bar_current_ratio"
const HEALTH_BAR_TARGET_RATIO_META_KEY := &"health_bar_target_ratio"
const HEALTH_BAR_ANIMATION_DURATION := 0.5
const STATUS_TEMPLATE_PATH := ^"state"
const STATUS_RUNTIME_NODE_PREFIX := "state_runtime_"
const STATUS_ICON_SPACING_X := 0.26
const MONSTER_STACK_SPACING_Z := BattleRoomScript.STACK_SPACING_Z + 0.8


func _apply_room_data(owner: Node) -> void:
	if owner.battle_room_data == null:
		return
	owner._player_ability_input_controller._cancel_selected_ability(owner, true)
	owner._player_ability_frame_states.clear()
	owner._monster_ability_frame_states.clear()
	owner._monster_sprite_states.clear()
	_apply_floor_textures(owner)
	_apply_player_sprite(owner)
	_apply_monster_sprites(owner)
	owner._player_ability_slot_states.clear()
	_apply_ability_frames(
		owner,
		owner.battle_room_data.get_player_abilities(),
		owner._player_ability_template,
		owner._generated_player_ability_frames,
		true
	)
	_apply_monster_ability_frames(owner)
	_apply_player_artifacts(owner)
	owner._player_ability_input_controller._refresh_player_ability_snap_state(owner)
	owner._update_turn_ui()


func _apply_floor_textures(owner: Node) -> void:
	if owner._floor == null:
		return
	var floor_texture = owner.battle_room_data.left_floor_texture
	if floor_texture == null:
		floor_texture = owner.battle_room_data.right_floor_texture
	_apply_texture_to_mesh(owner, owner._floor, floor_texture)


func _apply_player_sprite(owner: Node) -> void:
	var player_view = owner.battle_room_data.player_view
	owner._player_sprite.visible = player_view != null and player_view.sprite != null
	_set_status_template_visible(owner, false)
	if not owner._player_sprite.visible:
		return
	_apply_texture_to_mesh(owner, owner._player_sprite, player_view.sprite)
	owner._player_sprite.transform = Transform3D(Basis.from_scale(player_view.base_scale), BattleRoomScript.PLAYER_SPRITE_POSITION)
	_apply_health_bar(owner, owner._player_sprite, owner.battle_room_data.get_player_health_ratio())
	_apply_health_text(owner._player_sprite, owner.battle_room_data.get_player_health_values(), ^"HP_frame/HP_text_player")
	_apply_statuses_to_sprite(owner, owner._player_sprite, {"side": &"player"})


func _apply_monster_sprites(owner: Node) -> void:
	var previous_health_ratios := _capture_monster_health_ratios(owner._monster_sprite_states, owner)
	_clear_generated_nodes(owner, owner._generated_monster_sprites)
	owner._monster_sprite_states.clear()

	var monster_views = owner.battle_room_data.monster_views
	if monster_views.is_empty():
		owner._monster_sprite_template.visible = false
		return

	var offsets := _build_centered_offsets(monster_views.size(), MONSTER_STACK_SPACING_Z)
	for index in monster_views.size():
		var target_sprite = owner._monster_sprite_template if index == 0 else _duplicate_sprite_template(owner, owner._monster_sprite_template, owner._generated_monster_sprites)
		var monster_view = monster_views[index]
		var is_alive = owner.battle_room_data.can_target_monster(index)
		target_sprite.visible = is_alive and monster_view != null and monster_view.sprite != null
		if not target_sprite.visible:
			_clear_runtime_status_visuals(owner, target_sprite)
			continue
		_apply_texture_to_mesh(owner, target_sprite, monster_view.sprite)
		target_sprite.transform = Transform3D(
			Basis.from_scale(monster_view.base_scale),
			BattleRoomScript.MONSTER_SPRITE_POSITION + Vector3(0.0, 0.0, offsets[index])
		)
		var target_health_ratio = owner.battle_room_data.get_monster_health_ratio(index)
		var previous_health_ratio := float(previous_health_ratios.get(index, target_health_ratio))
		_apply_health_bar(owner, target_sprite, target_health_ratio, previous_health_ratio)
		_apply_monster_health_text(target_sprite, owner.battle_room_data.get_monster_health_values(index))
		_apply_statuses_to_sprite(owner, target_sprite, {"side": &"enemy", "index": index})
		owner._monster_sprite_states.append({
			"sprite": target_sprite,
			"index": index,
		})


func _capture_monster_health_ratios(monster_sprite_states: Array[Dictionary], owner: Node) -> Dictionary:
	var ratios := {}
	for monster_state in monster_sprite_states:
		var sprite := monster_state.get("sprite") as MeshInstance3D
		var monster_index := int(monster_state.get("index", -1))
		if sprite == null or monster_index < 0:
			continue
		var fallback_ratio = owner.battle_room_data.get_monster_health_ratio(monster_index)
		ratios[monster_index] = _resolve_health_bar_ratio(sprite, fallback_ratio)
	return ratios


func _apply_ability_frames(
	owner: Node,
	abilities: Array[AbilityDefinition],
	template: MeshInstance3D,
	generated_nodes: Array[Node],
	track_player_slots: bool = false
) -> void:
	_clear_generated_nodes(owner, generated_nodes)

	if abilities.is_empty():
		template.visible = false
		return

	var anchor := BattleRoomScript.PLAYER_ABILITY_FRAME_POSITION if template == owner._player_ability_template else BattleRoomScript.MONSTER_ABILITY_FRAME_POSITION
	var offsets := _build_centered_offsets(abilities.size(), BattleRoomScript.STACK_SPACING_Z)
	for index in abilities.size():
		var frame := template if index == 0 else _duplicate_frame_template(owner, template, generated_nodes)
		var ability := abilities[index]
		frame.visible = ability != null
		if ability == null:
			continue
		frame.transform = Transform3D(frame.transform.basis, anchor + Vector3(0.0, 0.0, offsets[index]))
		_apply_ability_icon(owner, frame, ability)
		_apply_ability_frame_rarity_visual(frame, ability)
		_apply_dice_places(frame, owner.battle_room_data.get_required_dice_slots(ability))
		if track_player_slots:
			owner._player_ability_input_controller._register_player_ability_frame(owner, frame, ability, index)
			owner._player_ability_input_controller._register_player_ability_slots(owner, frame, ability, index)


func _apply_monster_ability_frames(owner: Node) -> void:
	_clear_generated_nodes(owner, owner._generated_monster_ability_frames)
	owner._monster_ability_frame_states.clear()
	var monster_entries = owner.battle_room_data.get_monster_ability_entries()
	if monster_entries.is_empty():
		owner._monster_ability_template.visible = false
		return

	var offsets := _build_centered_offsets(monster_entries.size(), BattleRoomScript.STACK_SPACING_Z)
	for index in monster_entries.size():
		var frame = owner._monster_ability_template if index == 0 else _duplicate_frame_template(owner, owner._monster_ability_template, owner._generated_monster_ability_frames)
		var entry = monster_entries[index]
		var ability := entry.get("ability") as AbilityDefinition
		frame.visible = ability != null
		if ability == null:
			continue
		frame.transform = Transform3D(
			frame.transform.basis,
			BattleRoomScript.MONSTER_ABILITY_FRAME_POSITION + Vector3(0.0, 0.0, offsets[index])
		)
		_apply_ability_icon(owner, frame, ability)
		_apply_ability_frame_rarity_visual(frame, ability)
		_apply_dice_places(frame, owner.battle_room_data.get_required_dice_slots(ability))
		_register_monster_ability_frame(owner, frame, entry, index)


func _register_monster_ability_frame(owner: Node, frame: MeshInstance3D, ability_entry: Dictionary, runtime_index: int) -> void:
	owner._monster_ability_frame_states.append({
		"frame": frame,
		"ability": ability_entry.get("ability") as AbilityDefinition,
		"monster_index": int(ability_entry.get("monster_index", -1)),
		"monster_indexes": ability_entry.get("monster_indexes", PackedInt32Array()) as PackedInt32Array,
		"ability_index": int(ability_entry.get("ability_index", runtime_index)),
		"ability_indexes_by_monster": ability_entry.get("ability_indexes_by_monster", {}) as Dictionary,
		"base_origin": frame.transform.origin,
		"dice_places": _get_dice_place_nodes(frame),
	})


func _apply_player_artifacts(owner: Node) -> void:
	_clear_generated_artifact_icons(owner)
	if owner._artifact_template == null:
		return

	var active_artifacts: Array[ArtifactDefinition] = []
	if owner.battle_room_data != null and owner.battle_room_data.player_instance != null:
		active_artifacts = owner.battle_room_data.player_instance.get_active_artifact_definitions()

	if active_artifacts.is_empty():
		owner._artifact_template.visible = false
		return

	var template_position = owner._artifact_template.position
	var icon_step = owner._artifact_template.size * owner._artifact_template.scale
	if icon_step.x <= 0.0:
		icon_step.x = maxf(owner._artifact_template.get_combined_minimum_size().x * owner._artifact_template.scale.x, 1.0)
	if icon_step.y <= 0.0:
		icon_step.y = maxf(owner._artifact_template.get_combined_minimum_size().y * owner._artifact_template.scale.y, 1.0)

	var viewport_height := owner.get_viewport().get_visible_rect().size.y
	var available_height := maxf(viewport_height - template_position.y, icon_step.y)
	var rows_per_column := maxi(int(floor(available_height / icon_step.y)), 1)

	for artifact_index in active_artifacts.size():
		var artifact := active_artifacts[artifact_index]
		var icon = owner._artifact_template if artifact_index == 0 else _spawn_artifact_icon(owner)
		if icon == null:
			continue
		var column := artifact_index / rows_per_column
		var row := artifact_index % rows_per_column
		icon.position = template_position + Vector2(icon_step.x * float(column), icon_step.y * float(row))
		icon.texture = artifact.sprite if artifact != null and artifact.sprite != null else owner._artifact_template.texture
		icon.visible = true
		icon.tooltip_text = artifact.display_name if artifact != null else ""


func _spawn_artifact_icon(owner: Node) -> TextureRect:
	if owner._artifact_template == null or owner._artifact_template.get_parent() == null:
		return null
	var icon := owner._artifact_template.duplicate() as TextureRect
	if icon == null:
		return null
	icon.name = "artefact_%d" % owner._generated_artifact_icons.size()
	owner._artifact_template.get_parent().add_child(icon)
	owner._generated_artifact_icons.append(icon)
	return icon


func _clear_generated_artifact_icons(owner: Node) -> void:
	for icon in owner._generated_artifact_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	owner._generated_artifact_icons.clear()


func _apply_ability_icon(owner: Node, frame: MeshInstance3D, ability: AbilityDefinition) -> void:
	var icon_node := frame.get_node_or_null(^"player_ability") as MeshInstance3D
	if icon_node == null:
		icon_node = frame.get_node_or_null(^"monster_ability") as MeshInstance3D
	if icon_node == null:
		return
	icon_node.visible = ability.icon != null
	if icon_node.visible:
		_apply_texture_to_mesh(owner, icon_node, ability.icon)



func _apply_ability_frame_rarity_visual(frame: MeshInstance3D, ability: AbilityDefinition) -> void:
	if frame == null or ability == null:
		return
	RarityFrameVisuals.apply_base_frame_to_mesh_instance(frame, ability.rarity)

func _apply_dice_places(frame: MeshInstance3D, required_count: int) -> void:
	var dice_places := _get_dice_place_nodes(frame)
	if dice_places.is_empty():
		return

	var active_count := clampi(required_count, 0, dice_places.size())
	var base_positions := BattleRoomScript.DICE_PLACE_Z_POSITIONS
	var spacing := 0.0
	if base_positions.size() >= 2:
		spacing = absf(base_positions[1] - base_positions[0])
	var center = base_positions[1] if base_positions.size() >= 2 else 0.0

	var slot_positions := _build_centered_offsets(active_count, spacing)
	for index in dice_places.size():
		var dice_place := dice_places[index]
		if index >= active_count:
			dice_place.visible = false
			continue
		dice_place.visible = true
		var origin := dice_place.transform.origin
		origin.z = center + slot_positions[index]
		dice_place.transform = Transform3D(dice_place.transform.basis, origin)


func _get_dice_place_nodes(frame: MeshInstance3D) -> Array[MeshInstance3D]:
	var dice_places: Array[MeshInstance3D] = []
	for child in frame.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("dice_place"):
			dice_places.append(child as MeshInstance3D)
	dice_places.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool:
		return String(a.name) < String(b.name)
	)
	return dice_places


func _duplicate_sprite_template(owner: Node, template: MeshInstance3D, generated_nodes: Array[Node]) -> MeshInstance3D:
	var duplicate := template.duplicate() as MeshInstance3D
	duplicate.name = "%s_runtime_%d" % [template.name, generated_nodes.size()]
	owner.add_child(duplicate)
	generated_nodes.append(duplicate)
	return duplicate


func _duplicate_frame_template(owner: Node, template: MeshInstance3D, generated_nodes: Array[Node]) -> MeshInstance3D:
	var duplicate := template.duplicate() as MeshInstance3D
	duplicate.name = "%s_runtime_%d" % [template.name, generated_nodes.size()]
	owner.add_child(duplicate)
	generated_nodes.append(duplicate)
	return duplicate


func _clear_generated_nodes(_owner: Node, nodes: Array[Node]) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()


func _apply_health_bar(owner: Node, combatant_sprite: MeshInstance3D, health_ratio: float, initial_ratio: float = NAN) -> void:
	var resolved_ratio := clampf(health_ratio, 0.0, 1.0)
	var health_bar := _resolve_health_bar(combatant_sprite)
	if health_bar == null:
		return

	if not health_bar.has_meta(HEALTH_BAR_META_KEY):
		health_bar.set_meta(HEALTH_BAR_META_KEY, health_bar.transform)
	var resolved_initial_ratio := _resolve_health_bar_initial_ratio(health_bar, resolved_ratio, initial_ratio)
	health_bar.set_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY, resolved_initial_ratio)
	_update_health_bar_transform(health_bar, resolved_initial_ratio)
	health_bar.set_meta(HEALTH_BAR_TARGET_RATIO_META_KEY, resolved_ratio)


func _resolve_health_bar(combatant_sprite: MeshInstance3D) -> MeshInstance3D:
	if combatant_sprite == null:
		return null

	var health_bar := combatant_sprite.get_node_or_null(^"HP_frame/HP_bar_player") as MeshInstance3D
	if health_bar == null:
		health_bar = combatant_sprite.get_node_or_null(^"HP_frame_monster/HP_bar_monster") as MeshInstance3D
	return health_bar


func _resolve_health_bar_initial_ratio(health_bar: MeshInstance3D, fallback_ratio: float, initial_ratio: float) -> float:
	if not is_nan(initial_ratio):
		return clampf(initial_ratio, 0.0, 1.0)
	if health_bar != null and health_bar.has_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY):
		return clampf(float(health_bar.get_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY)), 0.0, 1.0)
	return clampf(fallback_ratio, 0.0, 1.0)


func _resolve_health_bar_ratio(combatant_sprite: MeshInstance3D, fallback_ratio: float) -> float:
	var health_bar := _resolve_health_bar(combatant_sprite)
	if health_bar == null:
		return clampf(fallback_ratio, 0.0, 1.0)
	if health_bar.has_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY):
		return clampf(float(health_bar.get_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY)), 0.0, 1.0)
	return clampf(fallback_ratio, 0.0, 1.0)


func _update_health_bar_transform(health_bar: MeshInstance3D, health_ratio: float) -> void:
	if health_bar == null or not health_bar.has_meta(HEALTH_BAR_META_KEY):
		return

	var resolved_ratio := clampf(health_ratio, 0.0, 1.0)
	var base_transform: Transform3D = health_bar.get_meta(HEALTH_BAR_META_KEY)
	var base_scale := base_transform.basis.get_scale()
	var target_scale_x := base_scale.x * resolved_ratio
	health_bar.visible = not is_zero_approx(target_scale_x)
	if not health_bar.visible:
		return

	var target_basis := Basis.from_scale(Vector3(target_scale_x, base_scale.y, base_scale.z))
	var target_origin := base_transform.origin
	target_origin.x = base_transform.origin.x - (base_scale.x - target_scale_x) * 1
	health_bar.transform = Transform3D(target_basis, target_origin)


func _animate_health_bar(_owner: Node, combatant_sprite: MeshInstance3D, target_ratio: float, delta: float) -> void:
	var health_bar := _resolve_health_bar(combatant_sprite)
	if health_bar == null:
		return
	if not health_bar.has_meta(HEALTH_BAR_META_KEY):
		health_bar.set_meta(HEALTH_BAR_META_KEY, health_bar.transform)
	if not health_bar.has_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY):
		health_bar.set_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY, clampf(target_ratio, 0.0, 1.0))

	var resolved_target_ratio := clampf(target_ratio, 0.0, 1.0)
	health_bar.set_meta(HEALTH_BAR_TARGET_RATIO_META_KEY, resolved_target_ratio)
	var current_ratio := float(health_bar.get_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY, resolved_target_ratio))
	var step := 1.0 if HEALTH_BAR_ANIMATION_DURATION <= 0.0 else minf(delta / HEALTH_BAR_ANIMATION_DURATION, 1.0)
	var next_ratio := move_toward(current_ratio, resolved_target_ratio, absf(resolved_target_ratio - current_ratio) * step)
	health_bar.set_meta(HEALTH_BAR_CURRENT_RATIO_META_KEY, next_ratio)
	_update_health_bar_transform(health_bar, next_ratio)


func _update_health_bars(owner: Node, delta: float) -> void:
	if owner.battle_room_data == null:
		return
	if owner.battle_room_data.player_view != null:
		_animate_health_bar(owner, owner._player_sprite, owner.battle_room_data.get_player_health_ratio(), delta)
		_apply_health_text(owner._player_sprite, owner.battle_room_data.get_player_health_values(), ^"HP_frame/HP_text_player")
	for monster_state in owner._monster_sprite_states:
		var sprite := monster_state.get("sprite") as MeshInstance3D
		var monster_index := int(monster_state.get("index", -1))
		if sprite == null or monster_index < 0:
			continue
		_animate_health_bar(owner, sprite, owner.battle_room_data.get_monster_health_ratio(monster_index), delta)
		_apply_monster_health_text(sprite, owner.battle_room_data.get_monster_health_values(monster_index))


func _apply_monster_health_text(combatant_sprite: MeshInstance3D, health_values: Vector2i) -> void:
	_apply_health_text(combatant_sprite, health_values, ^"HP_frame_monster/HP_text_monster")


func _apply_health_text(combatant_sprite: MeshInstance3D, health_values: Vector2i, label_path: NodePath) -> void:
	if combatant_sprite == null:
		return

	var health_label := combatant_sprite.get_node_or_null(label_path) as Label3D
	if health_label == null:
		return

	health_label.text = "%d/%d" % [maxi(health_values.x, 0), maxi(health_values.y, 0)]
	health_label.modulate = Color(1.0, 0.45, 0.75, 1.0)
	health_label.visible = health_values.y > 0


func _set_status_template_visible(owner: Node, is_visible: bool) -> void:
	var template := _get_status_template(owner)
	if template != null:
		template.visible = is_visible


func _get_status_template(owner: Node) -> MeshInstance3D:
	if owner._player_sprite == null:
		return null
	return owner._player_sprite.get_node_or_null(STATUS_TEMPLATE_PATH) as MeshInstance3D


func _clear_runtime_status_visuals(_owner: Node, combatant_sprite: MeshInstance3D) -> void:
	if combatant_sprite == null:
		return
	for child in combatant_sprite.get_children():
		if child is MeshInstance3D and String(child.name).begins_with(STATUS_RUNTIME_NODE_PREFIX):
			child.free()


func _apply_statuses_to_sprite(owner: Node, combatant_sprite: MeshInstance3D, descriptor: Dictionary) -> void:
	_clear_runtime_status_visuals(owner, combatant_sprite)
	if owner.battle_room_data == null or combatant_sprite == null:
		return

	var template := _get_status_template(owner)
	if template == null:
		return

	var status_container = owner.battle_room_data.get_status_container_for_descriptor(descriptor)
	if status_container == null:
		return
	var active_statuses = status_container.get_active_statuses()
	if active_statuses.is_empty():
		return
	var base_origin := template.transform.origin
	var base_basis := template.transform.basis
	var status_size_multiplier := _resolve_status_size_multiplier(owner, descriptor)
	var status_spacing_x := STATUS_ICON_SPACING_X
	if not is_equal_approx(status_size_multiplier, 1.0):
		base_basis = base_basis.scaled(Vector3.ONE / status_size_multiplier)
		status_spacing_x /= status_size_multiplier
	for index in active_statuses.size():
		var status_instance = active_statuses[index]
		if status_instance == null or status_instance.definition == null:
			continue
		var status_node := template.duplicate() as MeshInstance3D
		status_node.name = "%s%d" % [STATUS_RUNTIME_NODE_PREFIX, index]
		status_node.visible = true
		var icon_origin := base_origin + Vector3(status_spacing_x * index, 0.0, 0.0)
		status_node.transform = Transform3D(base_basis, icon_origin)
		combatant_sprite.add_child(status_node)
		if status_instance.definition.asset != null:
			_apply_texture_to_mesh(owner, status_node, status_instance.definition.asset)
		var stacks_label := status_node.get_node_or_null(^"state_stacks") as Label3D
		if stacks_label != null:
			stacks_label.text = str(maxi(status_instance.stacks, 0))


func _resolve_status_size_multiplier(owner: Node, descriptor: Dictionary) -> float:
	if owner.battle_room_data == null:
		return 1.0
	if descriptor.get("side", &"") != &"enemy":
		return 1.0
	var monster_index := int(descriptor.get("index", -1))
	var monster_view = owner.battle_room_data.get_monster_view(monster_index)
	if monster_view == null:
		return 1.0
	return clampf(float(monster_view.size_multiplier), 0.2, 2.0)


func _refresh_status_visuals(owner: Node) -> void:
	if owner.battle_room_data == null:
		return
	if owner._player_sprite != null and owner._player_sprite.visible:
		_apply_statuses_to_sprite(owner, owner._player_sprite, {"side": &"player"})
	for monster_state in owner._monster_sprite_states:
		var sprite := monster_state.get("sprite") as MeshInstance3D
		var monster_index := int(monster_state.get("index", -1))
		if sprite == null or monster_index < 0 or not sprite.visible:
			continue
		_apply_statuses_to_sprite(owner, sprite, {"side": &"enemy", "index": monster_index})


func _apply_texture_to_mesh(_owner: Node, mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	if mesh_instance == null:
		return
	var material := mesh_instance.material_override
	if material == null:
		material = StandardMaterial3D.new()
	else:
		material = material.duplicate()
	if material is StandardMaterial3D:
		material.albedo_texture = texture
	mesh_instance.material_override = material


func _build_centered_offsets(count: int, spacing: float) -> Array[float]:
	var offsets: Array[float] = []
	if count <= 0:
		return offsets
	var start := -0.5 * spacing * float(count - 1)
	for index in count:
		offsets.append(start + spacing * float(index))
	return offsets


func _set_mesh_tint(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return
	var material: StandardMaterial3D = null
	if mesh_instance.has_meta(TINT_MATERIAL_META_KEY):
		material = mesh_instance.get_meta(TINT_MATERIAL_META_KEY) as StandardMaterial3D
	if material == null:
		if mesh_instance.material_override is StandardMaterial3D:
			material = (mesh_instance.material_override as StandardMaterial3D).duplicate()
		else:
			material = StandardMaterial3D.new()
		mesh_instance.set_meta(TINT_MATERIAL_META_KEY, material)
		mesh_instance.material_override = material
	material.albedo_color = color
