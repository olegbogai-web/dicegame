extends Node3D
class_name BoardController

const DiceThrowRequestScript = preload("res://content/dice/dice_throw_request.gd")
const Dice = preload("res://content/dice/dice.gd")
const BattleServiceScript = preload("res://content/combat/services/battle_service.gd")
const BattleEnums = preload("res://content/combat/resources/battle_enums.gd")
const BattleRoomScript = preload("res://content/rooms/subclasses/battle_room.gd")
const TEST_MONSTER_DEFINITION = preload("res://content/monsters/definitions/test_monster.tres")

@export_category("Board References")
@export var floor_path: NodePath = ^"floor"
@export var default_dice_scene: PackedScene

@export_category("Spawn Bounds")
@export var spawn_bounds_margin: Vector2 = Vector2(0.15, 0.15)
@export var base_spawn_height: float = 0.7
@export var spawn_height_variation: float = 0.18
@export var spawn_spacing: float = 0.05
@export_range(1, 100, 1) var max_spawn_attempts: int = 24
@export var fallback_height_step: float = 0.3
@export var fallback_expand_step: Vector2 = Vector2(0.2, 0.2)

@export_category("Throw")
@export var throw_speed_min: float = 3.8
@export var throw_speed_max: float = 6.4
@export var throw_direction_spread: float = 1.25
@export var throw_vertical_velocity_min: float = 0.35
@export var throw_vertical_velocity_max: float = 1.4
@export var angular_velocity_min: Vector3 = Vector3(-14.0, -18.0, -14.0)
@export var angular_velocity_max: Vector3 = Vector3(14.0, 18.0, 14.0)

@onready var _floor: Node3D = get_node_or_null(floor_path)
@onready var _throw_button: Button = %ThrowDiceButton
@onready var _start_test_battle_button: Button = %StartTestBattleButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _status_label: Label = %BattleStatusLabel
@onready var _ability_buttons: HBoxContainer = %AbilityButtons
@onready var _target_buttons: HBoxContainer = %TargetButtons

var _rng := RandomNumberGenerator.new()
var _battle_service := BattleServiceScript.new()
var _battle_state: BattleState
var _selected_player_ability: AbilityDefinition
var _selected_player_dice_ids: Array[int] = []


func _ready() -> void:
	_rng.randomize()
	if _throw_button != null and not _throw_button.pressed.is_connected(_on_throw_button_pressed):
		_throw_button.pressed.connect(_on_throw_button_pressed)
	if _start_test_battle_button != null and not _start_test_battle_button.pressed.is_connected(_on_start_test_battle_pressed):
		_start_test_battle_button.pressed.connect(_on_start_test_battle_pressed)
	if _end_turn_button != null and not _end_turn_button.pressed.is_connected(_on_end_turn_button_pressed):
		_end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	_refresh_battle_ui()




func _physics_process(_delta: float) -> void:
	if _battle_state != null and not _battle_state.is_finished and _battle_state.phase == BattleEnums.Phase.AWAITING_PLAYER_ACTION:
		_refresh_battle_ui()

func throw_dice(requests: Array[DiceThrowRequest]) -> Array[RigidBody3D]:
	var spawned_dice: Array[RigidBody3D] = []
	var occupied_areas: Array[AABB] = []
	var board_center := _get_board_center()
	var spawn_extents := _get_spawn_extents()

	for request in requests:
		if request == null or request.dice_scene == null:
			push_warning("Skipped dice throw request because no scene was provided.")
			continue

		var instance := request.dice_scene.instantiate()
		if not instance is RigidBody3D:
			push_warning("Skipped dice throw request because the scene root is not a RigidBody3D.")
			if instance != null:
				instance.queue_free()
			continue

		var dice_body := instance as RigidBody3D
		var resolved_size := _resolve_request_size(dice_body, request)
		var spawn_result := _find_spawn_transform(resolved_size, occupied_areas, board_center, spawn_extents)
		var spawn_basis := Basis.from_euler(Vector3(
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI),
			_rng.randf_range(-PI, PI)
		))
		dice_body.mass = max(request.mass, 0.001)

		if dice_body is Dice:
			(dice_body as Dice).extra_size_multiplier = request.extra_size_multiplier

		add_child(dice_body)
		dice_body.global_transform = Transform3D(spawn_basis, spawn_result.origin)
		occupied_areas.append(_build_spawn_aabb(spawn_result.origin, resolved_size))

		var linear_velocity := _build_initial_velocity(spawn_result.origin, board_center)
		dice_body.linear_velocity = linear_velocity
		dice_body.angular_velocity = _random_vector3(angular_velocity_min, angular_velocity_max)
		if not spawn_result.found:
			push_warning("Fallback spawn was used for %s after exhausting spawn attempts." % dice_body.name)

		spawned_dice.append(dice_body)

	return spawned_dice


func throw_single_default_die() -> RigidBody3D:
	if default_dice_scene == null:
		push_warning("Default dice scene is not assigned.")
		return null

	var result := throw_dice([
		DiceThrowRequestScript.create(default_dice_scene)
	])
	return result[0] if not result.is_empty() else null


func _on_throw_button_pressed() -> void:
	if _has_active_battle():
		_status_label.text = "Во время боя кубы бросаются автоматически в начале хода."
		return
	throw_single_default_die()


func _on_start_test_battle_pressed() -> void:
	var battle_room := BattleRoomScript.create_test_battle_room()
	var monsters := [TEST_MONSTER_DEFINITION]
	_battle_state = _battle_service.create_test_battle(
		battle_room.player_instance,
		battle_room.player_view.sprite,
		monsters
	)
	_selected_player_ability = null
	_selected_player_dice_ids.clear()
	_sync_battle_table()
	_spawn_turn_dice()
	_refresh_battle_ui()


func _on_end_turn_button_pressed() -> void:
	if not _has_active_battle():
		return
	_selected_player_ability = null
	_selected_player_dice_ids.clear()
	_clear_spawned_dice()
	_battle_service.end_player_turn_and_run_monsters(_battle_state)
	_sync_battle_table()
	if not _battle_state.is_finished:
		_spawn_turn_dice()
	_refresh_battle_ui()


func _has_active_battle() -> bool:
	return _battle_state != null and not _battle_state.is_finished


func _spawn_turn_dice() -> void:
	_clear_spawned_dice()
	if _battle_state == null or _battle_state.active_turn == null or default_dice_scene == null:
		return
	var requests: Array[DiceThrowRequest] = []
	for die_data in _battle_state.active_turn.available_dice:
		var request := DiceThrowRequestScript.create(default_dice_scene)
		var definition: DiceDefinition = die_data.get("definition", null)
		if definition != null:
			request.size = definition.get_resolved_size()
		requests.append(request)
	var spawned := throw_dice(requests)
	for index in min(spawned.size(), _battle_state.active_turn.available_dice.size()):
		var body := spawned[index]
		if body is Dice:
			var die_node := body as Dice
			var die_data: Dictionary = _battle_state.active_turn.available_dice[index]
			var definition: DiceDefinition = die_data.get("definition", null)
			if definition != null:
				die_node.definition = definition
			die_node.set_meta("battle_dice_id", int(die_data.get("dice_id", -1)))
			die_node.set_meta("battle_value", int(die_data.get("value", 1)))


func _clear_spawned_dice() -> void:
	for child in get_children():
		if child is Dice and is_instance_valid(child):
			child.queue_free()


func _sync_battle_table() -> void:
	var battle_table := get_parent()
	if battle_table != null and battle_table.has_method("sync_from_battle_state"):
		battle_table.sync_from_battle_state(_battle_state)


func _refresh_battle_ui() -> void:
	for child in _ability_buttons.get_children():
		child.queue_free()
	for child in _target_buttons.get_children():
		child.queue_free()

	if _status_label == null:
		return

	if _battle_state == null:
		_status_label.text = "Нажмите «Начать тестовый бой», чтобы запустить бой."
		_end_turn_button.visible = false
		return

	_end_turn_button.visible = not _battle_state.is_finished
	if _battle_state.is_finished:
		_status_label.text = _battle_state.battle_log[_battle_state.battle_log.size() - 1] if not _battle_state.battle_log.is_empty() else "Бой завершен."
		return

	var active_combatant := _battle_state.get_combatant(_battle_state.active_combatant_id)
	if active_combatant != null:
		_status_label.text = "Раунд %d · Ход: %s" % [_battle_state.round_number, active_combatant.display_name]
	else:
		_status_label.text = "Бой активен."

	if _battle_state.phase != BattleEnums.Phase.AWAITING_PLAYER_ACTION:
		return

	var ready_abilities := _get_ready_player_abilities()
	if ready_abilities.is_empty():
		_status_label.text += " · Перетащите кубы в слоты способности или завершите ход."
		return

	for ready_entry in ready_abilities:
		var ability := ready_entry.get("ability") as AbilityDefinition
		if ability == null:
			continue
		var button := Button.new()
		button.text = ability.display_name
		button.pressed.connect(_on_player_ability_button_pressed.bind(ability, ready_entry.get("dice_ids", [])))
		_ability_buttons.add_child(button)

	if _selected_player_ability != null:
		_build_target_buttons(_selected_player_ability)


func _get_ready_player_abilities() -> Array[Dictionary]:
	_sync_runtime_dice_values_from_board()
	var battle_table := get_parent()
	if battle_table != null and battle_table.has_method("get_ready_player_abilities"):
		return battle_table.get_ready_player_abilities()
	return []


func _on_player_ability_button_pressed(ability: AbilityDefinition, dice_ids: Array) -> void:
	_selected_player_ability = ability
	_selected_player_dice_ids.clear()
	for dice_id in dice_ids:
		_selected_player_dice_ids.append(int(dice_id))
	_build_target_buttons(ability)
	if ability != null and ability.target_rule != null and ability.target_rule.selection == AbilityTargetRule.Selection.NONE:
		_confirm_player_ability(PackedStringArray([_battle_state.get_player().combatant_id]))


func _build_target_buttons(ability: AbilityDefinition) -> void:
	for child in _target_buttons.get_children():
		child.queue_free()
	if _battle_state == null or ability == null:
		return
	var targets := _battle_service.get_valid_player_targets(_battle_state, ability)
	for target in targets:
		if target == null:
			continue
		var button := Button.new()
		button.text = target.display_name
		button.pressed.connect(_on_target_button_pressed.bind(target.combatant_id))
		_target_buttons.add_child(button)


func _on_target_button_pressed(target_id: String) -> void:
	_confirm_player_ability(PackedStringArray([target_id]))


func _confirm_player_ability(target_ids: PackedStringArray) -> void:
	if _battle_state == null or _selected_player_ability == null:
		return
	_sync_runtime_dice_values_from_board()
	var result := _battle_service.activate_player_ability(_battle_state, _selected_player_ability, _selected_player_dice_ids, target_ids)
	if not result.get("ok", false):
		_status_label.text = "Не удалось активировать способность: %s" % String(result.get("reason", "unknown"))
		return
	_selected_player_ability = null
	_selected_player_dice_ids.clear()
	_sync_battle_table()
	_spawn_turn_dice()
	_refresh_battle_ui()




func _sync_runtime_dice_values_from_board() -> void:
	if _battle_state == null or _battle_state.active_turn == null:
		return
	var dice_by_id := {}
	for child in get_children():
		if child is Dice:
			var die_node := child as Dice
			var battle_dice_id := int(die_node.get_meta("battle_dice_id", -1))
			if battle_dice_id != -1:
				dice_by_id[battle_dice_id] = die_node.get_top_face_value()
	for die_data in _battle_state.active_turn.dice_pool.rolled_dice:
		var battle_dice_id := int(die_data.get("dice_id", -1))
		if dice_by_id.has(battle_dice_id):
			die_data["value"] = int(dice_by_id[battle_dice_id])
	_battle_state.active_turn.refresh_available_dice()

func _find_spawn_transform(
	resolved_size: Vector3,
	occupied_areas: Array[AABB],
	board_center: Vector3,
	spawn_extents: Vector2
) -> Dictionary:
	for attempt in max_spawn_attempts:
		var candidate_position := _random_spawn_position(resolved_size, board_center, spawn_extents)
		var candidate_aabb := _build_spawn_aabb(candidate_position, resolved_size)
		if not _intersects_spawned_dice(candidate_aabb, occupied_areas):
			return {
				"found": true,
				"origin": candidate_position,
			}

	var fallback_position := board_center + Vector3(
		_rng.randf_range(-fallback_expand_step.x, fallback_expand_step.x),
		base_spawn_height + spawn_height_variation + fallback_height_step * float(occupied_areas.size() + 1),
		_rng.randf_range(-fallback_expand_step.y, fallback_expand_step.y)
	)
	return {
		"found": false,
		"origin": fallback_position,
	}


func _random_spawn_position(resolved_size: Vector3, board_center: Vector3, spawn_extents: Vector2) -> Vector3:
	var allowed_x = max(spawn_extents.x - resolved_size.x * 0.5 - spawn_spacing, 0.0)
	var allowed_z = max(spawn_extents.y - resolved_size.z * 0.5 - spawn_spacing, 0.0)
	return Vector3(
		board_center.x + _rng.randf_range(-allowed_x, allowed_x),
		base_spawn_height + _rng.randf_range(0.0, spawn_height_variation),
		board_center.z + _rng.randf_range(-allowed_z, allowed_z)
	)


func _build_spawn_aabb(origin: Vector3, resolved_size: Vector3) -> AABB:
	var expanded_size := resolved_size + Vector3.ONE * spawn_spacing
	return AABB(origin - expanded_size * 0.5, expanded_size)


func _intersects_spawned_dice(candidate_aabb: AABB, occupied_areas: Array[AABB]) -> bool:
	for occupied_area in occupied_areas:
		if candidate_aabb.intersects(occupied_area):
			return true
	return false


func _build_initial_velocity(origin: Vector3, board_center: Vector3) -> Vector3:
	var to_center := board_center - origin
	var horizontal := Vector3(to_center.x, 0.0, to_center.z)
	if horizontal.length_squared() < 0.0001:
		horizontal = Vector3.FORWARD
	else:
		horizontal = horizontal.normalized()

	var spread := Vector3(
		_rng.randf_range(-throw_direction_spread, throw_direction_spread),
		0.0,
		_rng.randf_range(-throw_direction_spread, throw_direction_spread)
	)
	var direction := (horizontal + spread).normalized()
	var speed := _rng.randf_range(throw_speed_min, throw_speed_max)
	var vertical_velocity := _rng.randf_range(throw_vertical_velocity_min, throw_vertical_velocity_max)
	return direction * speed + Vector3.UP * vertical_velocity


func _resolve_request_size(dice_body: RigidBody3D, request: DiceThrowRequest) -> Vector3:
	if request.size != Vector3.ZERO:
		return request.size

	if dice_body is Dice and (dice_body as Dice).definition != null:
		var dice_definition := (dice_body as Dice).definition
		return dice_definition.get_resolved_size() * request.extra_size_multiplier

	for child in dice_body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			return (child.shape as BoxShape3D).size

	return Vector3.ONE * 0.2


func _get_board_center() -> Vector3:
	return _floor.global_position if _floor != null else global_position


func _get_spawn_extents() -> Vector2:
	if _floor == null:
		return Vector2.ONE

	var collision := _floor.get_node_or_null(^"collision") as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		var half_size := (collision.shape as BoxShape3D).size * 0.5
		var basis := collision.global_transform.basis
		var extents := Vector2(
			absf(basis.x.x) * half_size.x + absf(basis.y.x) * half_size.y + absf(basis.z.x) * half_size.z,
			absf(basis.x.z) * half_size.x + absf(basis.y.z) * half_size.y + absf(basis.z.z) * half_size.z
		)
		return Vector2(
			max(extents.x - spawn_bounds_margin.x, 0.1),
			max(extents.y - spawn_bounds_margin.y, 0.1)
		)

	return Vector2.ONE


func _random_vector3(min_value: Vector3, max_value: Vector3) -> Vector3:
	return Vector3(
		_rng.randf_range(min_value.x, max_value.x),
		_rng.randf_range(min_value.y, max_value.y),
		_rng.randf_range(min_value.z, max_value.z)
	)
