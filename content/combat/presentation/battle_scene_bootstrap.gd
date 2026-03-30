extends RefCounted
class_name BattleSceneBootstrap

const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")


func configure_from_battle_room(owner: Node, next_battle_room: BattleRoom) -> void:
	owner.battle_room_data = next_battle_room
	owner._has_spawned_post_battle_reward_dice = false
	owner._is_waiting_post_battle_reward_dice = false
	owner._has_processed_post_battle_reward_result = false
	owner._clear_ability_reward_cards()
	if owner.is_node_ready():
		owner._apply_room_data()
		_initialize_battle_state(owner)


func set_floor_textures(owner: Node, left_texture: Texture2D, right_texture: Texture2D) -> void:
	_ensure_battle_room_data(owner)
	owner.battle_room_data.set_floor_textures(left_texture, right_texture)
	if owner.is_node_ready():
		owner._apply_floor_textures()


func set_player_data(owner: Node, player: Player, sprite: Texture2D) -> void:
	_ensure_battle_room_data(owner)
	owner.battle_room_data.set_player_data(player, sprite)
	if owner.is_node_ready():
		owner._apply_room_data()
		_initialize_battle_state(owner)


func set_monsters(owner: Node, monster_definitions: Array[MonsterDefinition]) -> void:
	_ensure_battle_room_data(owner)
	owner.battle_room_data.set_monsters_from_definitions(monster_definitions)
	if owner.is_node_ready():
		owner._apply_room_data()
		_initialize_battle_state(owner)


func _initialize_battle_state(owner: Node) -> void:
	if owner.battle_room_data == null:
		return
	if owner.battle_room_data.player_instance != null:
		owner.battle_room_data.player_instance.ensure_runtime_from_base_stat()
		owner.battle_room_data.set_player_data(owner.battle_room_data.player_instance, owner.battle_room_data.player_view.sprite)
	if owner.battle_room_data.battle_status == &"not_started":
		owner._has_spawned_post_battle_reward_dice = false
		owner._is_waiting_post_battle_reward_dice = false
		owner._has_processed_post_battle_reward_result = false
		owner._clear_ability_reward_cards()
		owner.battle_room_data.start_battle()
	owner._start_current_turn()


func _ensure_battle_room_data(owner: Node) -> void:
	if owner.battle_room_data == null:
		owner.battle_room_data = BattleRoomScript.new()
