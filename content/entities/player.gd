extends RefCounted
class_name Player

var player_id := ""
var base_stat: PlayerBaseStat
var current_hp := 0
var current_armor := 0
var dice_loadout: Array[DiceDefinition] = []
var runtime_cube_global_map: Array[DiceDefinition] = []
var runtime_reward_cube: DiceDefinition
var runtime_money_cube: DiceDefinition
var ability_loadout: Array[AbilityDefinition] = []
var artifacts_runtime: Array[ArtifactDefinition] = []
var run_flags: Dictionary = {}
var metadata: Dictionary = {}


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
		dice_loadout.clear()
		runtime_cube_global_map.clear()
		runtime_reward_cube = null
		runtime_money_cube = null
		ability_loadout.clear()
		artifacts_runtime.clear()
		run_flags.clear()
		return
	current_hp = base_stat.get_resolved_starting_hp()
	current_armor = base_stat.starting_armor
	dice_loadout = base_stat.starting_dice.duplicate()
	runtime_cube_global_map = base_stat.get_resolved_base_cube_global_map().duplicate(true)
	runtime_reward_cube = base_stat.get_resolved_base_reward_cube().duplicate(true)
	runtime_money_cube = base_stat.get_resolved_base_money_cube().duplicate(true)
	ability_loadout = base_stat.get_resolved_starting_abilities().duplicate()
	artifacts_runtime.clear()
	run_flags.clear()


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
	current_hp = mini(current_hp + resolved_amount, base_stat.max_hp)
	return current_hp - previous_hp


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
