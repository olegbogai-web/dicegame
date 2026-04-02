extends RefCounted
class_name Player

const ON_GRANT_MAX_HP_BONUS_META_KEY := &"on_grant_max_hp_bonus"
const MAX_ABILITY_SLOTS := 5

signal coins_changed(total_coins: int)

var player_id := ""
var base_stat: PlayerBaseStat
var current_hp := 0
var current_armor := 0
var current_coins := 0
var dice_loadout: Array[DiceDefinition] = []
var runtime_cube_global_map: Array[DiceDefinition] = []
var runtime_reward_cube: DiceDefinition
var runtime_money_cube: DiceDefinition
var runtime_reward_cubes: Array[DiceDefinition] = []
var runtime_money_cubes: Array[DiceDefinition] = []
var runtime_event_cubes: Array[DiceDefinition] = []
var ability_loadout: Array[AbilityDefinition] = []
var artifacts_runtime: Array[ArtifactDefinition] = []
var runtime_max_hp_bonus := 0
var run_flags: Dictionary = {}
var metadata: Dictionary = {}
var _is_runtime_initialized := false


func _init(initial_base_stat: PlayerBaseStat = null) -> void:
	if initial_base_stat != null:
		apply_base_stat(initial_base_stat)


func apply_base_stat(next_base_stat: PlayerBaseStat) -> void:
	if next_base_stat == null:
		return
	base_stat = next_base_stat
	player_id = next_base_stat.player_id
	metadata = next_base_stat.metadata.duplicate(true)
	reset_for_run()


func reset_for_run() -> void:
	if base_stat == null:
		current_hp = 0
		current_armor = 0
		current_coins = 0
		dice_loadout.clear()
		runtime_cube_global_map.clear()
		runtime_reward_cube = null
		runtime_money_cube = null
		runtime_reward_cubes.clear()
		runtime_money_cubes.clear()
		runtime_event_cubes.clear()
		ability_loadout.clear()
		artifacts_runtime.clear()
		runtime_max_hp_bonus = 0
		run_flags.clear()
		_is_runtime_initialized = false
		_emit_coins_changed()
		return
	current_hp = base_stat.get_resolved_starting_hp()
	current_armor = base_stat.starting_armor
	current_coins = maxi(base_stat.starting_coins, 0)
	dice_loadout = base_stat.starting_dice.duplicate()
	runtime_cube_global_map = base_stat.get_resolved_base_cube_global_map().duplicate(true)
	runtime_reward_cube = base_stat.get_resolved_base_reward_cube().duplicate(true)
	runtime_money_cube = base_stat.get_resolved_base_money_cube().duplicate(true)
	runtime_reward_cubes = []
	runtime_money_cubes = []
	runtime_event_cubes = []
	if runtime_reward_cube != null:
		runtime_reward_cubes.append(runtime_reward_cube)
	if runtime_money_cube != null:
		runtime_money_cubes.append(runtime_money_cube)
	ability_loadout.clear()
	for starting_ability in base_stat.starting_abilities:
		grant_ability(starting_ability)
	artifacts_runtime.clear()
	runtime_max_hp_bonus = 0
	run_flags.clear()
	_is_runtime_initialized = true
	_emit_coins_changed()


func ensure_runtime_initialized_from_base_stat() -> void:
	if base_stat == null:
		return
	if _is_runtime_initialized:
		return
	reset_for_run()


func is_alive() -> bool:
	return current_hp > 0


func take_damage(amount: int) -> int:
	var incoming_damage := maxi(amount, 0)
	var blocked_damage := mini(current_armor, incoming_damage)
	current_armor -= blocked_damage
	var hp_damage := incoming_damage - blocked_damage
	current_hp = maxi(current_hp - hp_damage, 0)
	return hp_damage


func heal(amount: int) -> int:
	if base_stat == null:
		return 0
	var resolved_amount := maxi(amount, 0)
	var previous_hp := current_hp
	current_hp = mini(current_hp + resolved_amount, get_max_hp())
	return current_hp - previous_hp


func get_max_hp() -> int:
	if base_stat == null:
		return 0
	return maxi(base_stat.max_hp + runtime_max_hp_bonus, 0)


func add_coins(amount: int) -> int:
	var resolved_amount := maxi(amount, 0)
	if resolved_amount <= 0:
		return current_coins
	current_coins += resolved_amount
	_emit_coins_changed()
	return current_coins


func spend_coins(amount: int) -> bool:
	var resolved_amount := maxi(amount, 0)
	if resolved_amount <= 0:
		return true
	if current_coins < resolved_amount:
		return false
	current_coins -= resolved_amount
	_emit_coins_changed()
	return true


func set_coins(amount: int) -> void:
	current_coins = maxi(amount, 0)
	_emit_coins_changed()


func grant_artifact(artifact_definition: ArtifactDefinition) -> void:
	if artifact_definition == null:
		return
	artifacts_runtime.append(artifact_definition)
	_apply_on_grant_effects(artifact_definition)


func grant_ability(ability_definition: AbilityDefinition, rng: RandomNumberGenerator = null) -> void:
	if ability_definition == null:
		return
	if ability_loadout.size() >= MAX_ABILITY_SLOTS:
		var random_source := rng
		if random_source == null:
			random_source = RandomNumberGenerator.new()
			random_source.randomize()
		var remove_index := random_source.randi_range(0, ability_loadout.size() - 1)
		ability_loadout.remove_at(remove_index)
	ability_loadout.append(ability_definition)


func get_active_artifact_definitions() -> Array[ArtifactDefinition]:
	var resolved: Array[ArtifactDefinition] = []
	if base_stat != null:
		for artifact_definition in base_stat.get_resolved_artifacts_base():
			if artifact_definition != null:
				resolved.append(artifact_definition)
	for artifact_runtime in artifacts_runtime:
		if artifact_runtime != null:
			resolved.append(artifact_runtime)
	return resolved


func grant_runtime_cube(cube_definition: DiceDefinition) -> void:
	if cube_definition == null:
		return
	var cloned_cube := cube_definition.duplicate(true) as DiceDefinition
	if cloned_cube == null:
		return
	match cloned_cube.scope:
		DiceDefinition.Scope.COMBAT:
			dice_loadout.append(cloned_cube)
		DiceDefinition.Scope.GLOBAL_MAP:
			runtime_cube_global_map.append(cloned_cube)
		DiceDefinition.Scope.REWARD:
			runtime_reward_cubes.append(cloned_cube)
			runtime_reward_cube = runtime_reward_cubes[0] if not runtime_reward_cubes.is_empty() else null
		DiceDefinition.Scope.MONEY:
			runtime_money_cubes.append(cloned_cube)
			runtime_money_cube = runtime_money_cubes[0] if not runtime_money_cubes.is_empty() else null
		DiceDefinition.Scope.EVENT:
			runtime_event_cubes.append(cloned_cube)


func get_runtime_cubes_by_scope(scope: int) -> Array[DiceDefinition]:
	match scope:
		DiceDefinition.Scope.COMBAT:
			return dice_loadout
		DiceDefinition.Scope.GLOBAL_MAP:
			return runtime_cube_global_map
		DiceDefinition.Scope.REWARD:
			return runtime_reward_cubes
		DiceDefinition.Scope.MONEY:
			return runtime_money_cubes
		DiceDefinition.Scope.EVENT:
			return runtime_event_cubes
	return []


func _apply_on_grant_effects(artifact_definition: ArtifactDefinition) -> void:
	if artifact_definition == null:
		return
	var max_hp_bonus := maxi(int(artifact_definition.metadata.get(ON_GRANT_MAX_HP_BONUS_META_KEY, 0)), 0)
	if max_hp_bonus <= 0:
		return
	runtime_max_hp_bonus += max_hp_bonus
	current_hp = mini(current_hp + max_hp_bonus, get_max_hp())


func _emit_coins_changed() -> void:
	coins_changed.emit(current_coins)
