extends Node3D

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")
const Dice = preload("res://content/dice/dice.gd")

const SLOT_EMPTY_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const SLOT_ASSIGNED_COLOR := Color(0.82, 0.9, 1.0, 1.0)
const SLOT_READY_COLOR := Color(0.2, 0.62, 1.0, 1.0)
const FRAME_READY_COLOR := Color(0.12, 0.55, 1.0, 1.0)
const TINT_MATERIAL_META_KEY := &"runtime_tint_material"

@onready var _camera: Camera3D = $Camera3D
@onready var _board: Node3D = $board
@onready var _left_floor: MeshInstance3D = $left_floor
@onready var _right_floor: MeshInstance3D = $right_floor
@onready var _player_sprite: MeshInstance3D = $player_sprite
@onready var _monster_sprite_template: MeshInstance3D = $monster_sprite
@onready var _player_ability_template: MeshInstance3D = $ability_frame
@onready var _monster_ability_template: MeshInstance3D = $ability_frame2

const HEALTH_BAR_META_KEY := &"health_bar_base_transform"

var battle_room_data: BattleRoom
var _generated_monster_sprites: Array[Node] = []
var _generated_player_ability_frames: Array[Node] = []
var _generated_monster_ability_frames: Array[Node] = []
var _player_ability_slot_states: Array[Dictionary] = []


func _ready() -> void:
	set_physics_process(true)
	if battle_room_data == null:
		configure_from_battle_room(BattleRoomScript.create_test_battle_room())
	else:
		_apply_room_data()


func configure_from_battle_room(next_battle_room: BattleRoom) -> void:
	battle_room_data = next_battle_room
	if is_node_ready():
		_apply_room_data()


func set_floor_textures(left_texture: Texture2D, right_texture: Texture2D) -> void:
	_ensure_battle_room_data()
	battle_room_data.set_floor_textures(left_texture, right_texture)
	if is_node_ready():
		_apply_floor_textures()


func set_player_data(player: Player, sprite: Texture2D) -> void:
	_ensure_battle_room_data()
	battle_room_data.set_player_data(player, sprite)
	if is_node_ready():
		_apply_room_data()


func set_monsters(monster_definitions: Array[MonsterDefinition]) -> void:
	_ensure_battle_room_data()
	battle_room_data.set_monsters_from_definitions(monster_definitions)
	if is_node_ready():
		_apply_room_data()


func _ensure_battle_room_data() -> void:
	if battle_room_data == null:
		battle_room_data = BattleRoomScript.new()


func _apply_room_data() -> void:
	if battle_room_data == null:
		return
	_apply_floor_textures()
	_apply_player_sprite()
	_apply_monster_sprites()
	_player_ability_slot_states.clear()
	_apply_ability_frames(
		battle_room_data.get_player_abilities(),
		_player_ability_template,
		_generated_player_ability_frames,
		true
	)
	_apply_ability_frames(
		battle_room_data.get_monster_abilities(),
		_monster_ability_template,
		_generated_monster_ability_frames
	)
	_refresh_player_ability_snap_state()


func _apply_floor_textures() -> void:
	_apply_texture_to_mesh(_left_floor, battle_room_data.left_floor_texture)
	_apply_texture_to_mesh(_right_floor, battle_room_data.right_floor_texture)


func _apply_player_sprite() -> void:
	var player_view := battle_room_data.player_view
	_player_sprite.visible = player_view != null and player_view.sprite != null
	if not _player_sprite.visible:
		return
	_apply_texture_to_mesh(_player_sprite, player_view.sprite)
	_player_sprite.transform = Transform3D(Basis.from_scale(player_view.base_scale), BattleRoomScript.PLAYER_SPRITE_POSITION)
	_apply_health_bar(_player_sprite, battle_room_data.get_player_health_ratio())


func _apply_monster_sprites() -> void:
	_clear_generated_nodes(_generated_monster_sprites)

	var monster_views := battle_room_data.monster_views
	if monster_views.is_empty():
		_monster_sprite_template.visible = false
		return

	var offsets := _build_centered_offsets(monster_views.size(), BattleRoomScript.STACK_SPACING_Z)
	for index in monster_views.size():
		var target_sprite := _monster_sprite_template if index == 0 else _duplicate_sprite_template(_monster_sprite_template, _generated_monster_sprites)
		var monster_view = monster_views[index]
		target_sprite.visible = monster_view != null and monster_view.sprite != null
		if not target_sprite.visible:
			continue
		_apply_texture_to_mesh(target_sprite, monster_view.sprite)
		target_sprite.transform = Transform3D(
			Basis.from_scale(monster_view.base_scale),
			BattleRoomScript.MONSTER_SPRITE_POSITION + Vector3(0.0, 0.0, offsets[index])
		)
		_apply_health_bar(target_sprite, battle_room_data.get_monster_health_ratio(index))


func _apply_ability_frames(
	abilities: Array[AbilityDefinition],
	template: MeshInstance3D,
	generated_nodes: Array[Node],
	track_player_slots: bool = false
) -> void:
	_clear_generated_nodes(generated_nodes)

	if abilities.is_empty():
		template.visible = false
		return

	var anchor := BattleRoomScript.PLAYER_ABILITY_FRAME_POSITION if template == _player_ability_template else BattleRoomScript.MONSTER_ABILITY_FRAME_POSITION
	var offsets := _build_centered_offsets(abilities.size(), BattleRoomScript.STACK_SPACING_Z)
	for index in abilities.size():
		var frame := template if index == 0 else _duplicate_frame_template(template, generated_nodes)
		var ability := abilities[index]
		frame.visible = ability != null
		if ability == null:
			continue
		frame.transform = Transform3D(frame.transform.basis, anchor + Vector3(0.0, 0.0, offsets[index]))
		_apply_ability_icon(frame, ability)
		_apply_dice_places(frame, battle_room_data.get_required_dice_slots(ability))
		if track_player_slots:
			_register_player_ability_slots(frame, ability, index)


func _apply_ability_icon(frame: MeshInstance3D, ability: AbilityDefinition) -> void:
	var icon_node := frame.get_node_or_null(^"player_ability") as MeshInstance3D
	if icon_node == null:
		icon_node = frame.get_node_or_null(^"monster_ability") as MeshInstance3D
	if icon_node == null:
		return
	icon_node.visible = ability.icon != null
	if icon_node.visible:
		_apply_texture_to_mesh(icon_node, ability.icon)


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


func _duplicate_sprite_template(template: MeshInstance3D, generated_nodes: Array[Node]) -> MeshInstance3D:
	var duplicate := template.duplicate() as MeshInstance3D
	duplicate.name = "%s_runtime_%d" % [template.name, generated_nodes.size()]
	add_child(duplicate)
	generated_nodes.append(duplicate)
	return duplicate


func _duplicate_frame_template(template: MeshInstance3D, generated_nodes: Array[Node]) -> MeshInstance3D:
	var duplicate := template.duplicate() as MeshInstance3D
	duplicate.name = "%s_runtime_%d" % [template.name, generated_nodes.size()]
	add_child(duplicate)
	generated_nodes.append(duplicate)
	return duplicate


func _clear_generated_nodes(nodes: Array[Node]) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()


func _apply_health_bar(combatant_sprite: MeshInstance3D, health_ratio: float) -> void:
	if combatant_sprite == null:
		return

	var health_bar := combatant_sprite.get_node_or_null(^"HP_frame/HP_bar_player") as MeshInstance3D
	if health_bar == null:
		health_bar = combatant_sprite.get_node_or_null(^"HP_frame_monster/HP_bar_monster") as MeshInstance3D
	if health_bar == null:
		return

	var resolved_ratio := clampf(health_ratio, 0.0, 1.0)
	if not health_bar.has_meta(HEALTH_BAR_META_KEY):
		health_bar.set_meta(HEALTH_BAR_META_KEY, health_bar.transform)

	var base_transform: Transform3D = health_bar.get_meta(HEALTH_BAR_META_KEY)
	var base_scale := base_transform.basis.get_scale()
	var target_scale_x := base_scale.x * resolved_ratio
	health_bar.visible = not is_zero_approx(target_scale_x)
	if not health_bar.visible:
		return

	var target_basis := Basis.from_scale(Vector3(target_scale_x, base_scale.y, base_scale.z))
	var target_origin := base_transform.origin
	target_origin.x = base_transform.origin.x - (base_scale.x - target_scale_x) * 0.5
	health_bar.transform = Transform3D(target_basis, target_origin)


func _apply_texture_to_mesh(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
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


func _physics_process(_delta: float) -> void:
	_refresh_player_ability_snap_state()


func _refresh_player_ability_snap_state() -> void:
	if _player_ability_slot_states.is_empty():
		return

	var dice_list := _get_board_dice()
	var slot_by_id := {}
	for slot_state in _player_ability_slot_states:
		slot_by_id[slot_state["slot_id"]] = slot_state

	for dice in dice_list:
		var assigned_slot_id := dice.get_assigned_ability_slot_id()
		if assigned_slot_id == &"":
			continue
		if not slot_by_id.has(assigned_slot_id):
			dice.clear_ability_slot()
			continue
		var assigned_slot: Dictionary = slot_by_id[assigned_slot_id]
		if not _dice_matches_slot(dice, assigned_slot):
			dice.clear_ability_slot()

	var used_dice := {}
	for slot_state in _player_ability_slot_states:
		var assigned_dice := _find_dice_for_slot(slot_state, dice_list)
		if assigned_dice != null:
			used_dice[assigned_dice.get_instance_id()] = true
			var target_position := _get_slot_target_position(slot_state["dice_place"], assigned_dice)
			assigned_dice.assign_ability_slot(slot_state["slot_id"], target_position)
			continue

		var candidate := _find_snap_candidate(slot_state, dice_list, used_dice)
		if candidate == null:
			continue
		used_dice[candidate.get_instance_id()] = true
		candidate.assign_ability_slot(slot_state["slot_id"], _get_slot_target_position(slot_state["dice_place"], candidate))

	_update_player_ability_visuals(dice_list)


func _register_player_ability_slots(frame: MeshInstance3D, ability: AbilityDefinition, ability_index: int) -> void:
	var dice_places := _get_dice_place_nodes(frame)
	var slot_conditions := _build_slot_conditions(ability)
	for index in dice_places.size():
		var dice_place := dice_places[index]
		if index >= slot_conditions.size() or not dice_place.visible:
			continue
		_player_ability_slot_states.append({
			"slot_id": StringName("player_%s_%d_%d" % [ability.ability_id, ability_index, index]),
			"ability_id": ability.ability_id,
			"ability": ability,
			"frame": frame,
			"dice_place": dice_place,
			"condition": slot_conditions[index],
		})


func _build_slot_conditions(ability: AbilityDefinition) -> Array[AbilityDiceCondition]:
	var conditions: Array[AbilityDiceCondition] = []
	if ability == null or ability.cost == null:
		return conditions
	for dice_condition in ability.cost.dice_conditions:
		if dice_condition == null:
			continue
		for _count in maxi(dice_condition.required_count, 0):
			conditions.append(dice_condition)
	return conditions


func _get_board_dice() -> Array[Dice]:
	var dice_list: Array[Dice] = []
	if _board == null:
		return dice_list
	for child in _board.get_children():
		if child is Dice and is_instance_valid(child):
			dice_list.append(child as Dice)
	return dice_list


func _find_dice_for_slot(slot_state: Dictionary, dice_list: Array[Dice]) -> Dice:
	for dice in dice_list:
		if dice.get_assigned_ability_slot_id() == slot_state["slot_id"]:
			return dice
	return null


func _find_snap_candidate(slot_state: Dictionary, dice_list: Array[Dice], used_dice: Dictionary) -> Dice:
	var best_candidate: Dice
	var best_distance := INF
	var dice_place := slot_state["dice_place"] as MeshInstance3D
	for dice in dice_list:
		if used_dice.has(dice.get_instance_id()):
			continue
		if dice.is_being_dragged() or dice.get_assigned_ability_slot_id() != &"":
			continue
		if not _dice_matches_slot(dice, slot_state):
			continue
		var distance := dice.global_position.distance_to(_get_slot_target_position(dice_place, dice))
		if distance > dice.ability_snap_distance or distance >= best_distance:
			continue
		best_distance = distance
		best_candidate = dice
	return best_candidate


func _dice_matches_slot(dice: Dice, slot_state: Dictionary) -> bool:
	var condition := slot_state.get("condition") as AbilityDiceCondition
	if dice == null or condition == null:
		return false

	var top_face_value := dice.get_top_face_value()
	if top_face_value < 0 or not condition.matches_value(top_face_value):
		return false

	if condition.requires_face_filter():
		var top_face := dice.get_top_face()
		if top_face == null or not condition.accepted_face_ids.has(top_face.text_value):
			return false

	var dice_tags := dice.get_match_tags()
	for required_tag in condition.required_tags:
		if not dice_tags.has(required_tag):
			return false
	for forbidden_tag in condition.forbidden_tags:
		if dice_tags.has(forbidden_tag):
			return false

	return _dice_satisfies_use_conditions(dice, slot_state.get("ability") as AbilityDefinition)


func _dice_satisfies_use_conditions(dice: Dice, ability: AbilityDefinition) -> bool:
	if dice == null or ability == null:
		return false

	for condition in ability.use_conditions:
		if condition == null:
			continue
		if condition.predicate == &"selected_die_top_face_parity":
			var parity := String(condition.parameters.get("parity", ""))
			var top_face_value := dice.get_top_face_value()
			if parity == "even" and top_face_value % 2 != 0:
				return false
			if parity == "odd" and top_face_value % 2 == 0:
				return false

	return true


func _get_slot_target_position(dice_place: MeshInstance3D, dice: Dice) -> Vector3:
	var offset_y := 0.1
	if dice != null and dice.definition != null:
		offset_y = dice.definition.get_resolved_size().y * dice.extra_size_multiplier.y * 0.5
	return dice_place.global_position + Vector3.UP * offset_y


func _update_player_ability_visuals(dice_list: Array[Dice]) -> void:
	var ability_status := {}
	for slot_state in _player_ability_slot_states:
		var assigned_dice := _find_dice_for_slot(slot_state, dice_list)
		var is_ready := assigned_dice != null and assigned_dice.is_snapped_to_ability_slot()
		var slot_color := SLOT_EMPTY_COLOR
		if assigned_dice != null:
			slot_color = SLOT_ASSIGNED_COLOR
		if is_ready:
			slot_color = SLOT_READY_COLOR
		_set_mesh_tint(slot_state["dice_place"], slot_color)
		var ability_key := (slot_state["frame"] as MeshInstance3D).get_instance_id()
		if not ability_status.has(ability_key):
			ability_status[ability_key] = {
				"frame": slot_state["frame"],
				"ready": true,
			}
		if not is_ready:
			ability_status[ability_key]["ready"] = false

	for slot_info in ability_status.values():
		_set_mesh_tint(slot_info["frame"], FRAME_READY_COLOR if slot_info["ready"] else SLOT_EMPTY_COLOR)


func _set_mesh_tint(mesh_instance: MeshInstance3D, color: Color) -> void:
	if mesh_instance == null:
		return
	var material := mesh_instance.get_meta(TINT_MATERIAL_META_KEY, null) as StandardMaterial3D
	if material == null:
		if mesh_instance.material_override is StandardMaterial3D:
			material = (mesh_instance.material_override as StandardMaterial3D).duplicate()
		else:
			material = StandardMaterial3D.new()
		mesh_instance.set_meta(TINT_MATERIAL_META_KEY, material)
		mesh_instance.material_override = material
	material.albedo_color = color
