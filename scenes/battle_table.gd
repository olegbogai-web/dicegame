extends Node3D

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")

@onready var _camera: Camera3D = $Camera3D
@onready var _board: Node3D = $board
@onready var _left_floor: MeshInstance3D = $left_floor
@onready var _right_floor: MeshInstance3D = $right_floor
@onready var _player_sprite: MeshInstance3D = $player_sprite
@onready var _monster_sprite_template: MeshInstance3D = $monster_sprite
@onready var _player_ability_template: MeshInstance3D = $ability_frame
@onready var _monster_ability_template: MeshInstance3D = $ability_frame2

var battle_room_data: BattleRoom
var _generated_monster_sprites: Array[Node] = []
var _generated_player_ability_frames: Array[Node] = []
var _generated_monster_ability_frames: Array[Node] = []


func _ready() -> void:
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
	_apply_ability_frames(
		battle_room_data.get_player_abilities(),
		_player_ability_template,
		_generated_player_ability_frames
	)
	_apply_ability_frames(
		battle_room_data.get_monster_abilities(),
		_monster_ability_template,
		_generated_monster_ability_frames
	)


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


func _apply_ability_frames(
	abilities: Array[AbilityDefinition],
	template: MeshInstance3D,
	generated_nodes: Array[Node]
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
	var center := base_positions[1] if base_positions.size() >= 2 else 0.0

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
