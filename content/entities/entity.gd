extends RefCounted
class_name Entity

const EntityStatsContainerScript = preload("res://content/entities/runtime/entity_stats_container.gd")
const EntityStatusContainerScript = preload("res://content/entities/runtime/entity_status_container.gd")
const EntityAbilityLoadoutScript = preload("res://content/entities/runtime/entity_ability_loadout.gd")
const EntityDiceLoadoutScript = preload("res://content/entities/runtime/entity_dice_loadout.gd")

enum EntityType {
	PLAYER,
	MONSTER,
}

enum Faction {
	PLAYER,
	ENEMY,
	NEUTRAL,
}

var entity_id: StringName = StringName()
var entity_type: EntityType = EntityType.PLAYER
var faction: Faction = Faction.PLAYER
var tags: PackedStringArray = PackedStringArray()
var behavior_tags: PackedStringArray = PackedStringArray()
var current_hp := 0
var max_hp_override := -1
var is_dead := false
var metadata: Dictionary = {}

var stats: EntityStatsContainer
var statuses: EntityStatusContainer
var abilities: EntityAbilityLoadout
var dice_loadout: EntityDiceLoadout


func _init() -> void:
	stats = EntityStatsContainerScript.new()
	statuses = EntityStatusContainerScript.new()
	abilities = EntityAbilityLoadoutScript.new()
	dice_loadout = EntityDiceLoadoutScript.new()


func configure_identity(id: StringName, entity_kind: EntityType, entity_faction: Faction) -> Entity:
	entity_id = id
	entity_type = entity_kind
	faction = entity_faction
	_refresh_lifecycle_state()
	return self


func set_current_hp(value: int) -> void:
	current_hp = max(value, 0)
	_refresh_lifecycle_state()


func set_max_hp_override(value: int) -> void:
	max_hp_override = value
	if current_hp > get_max_hp():
		current_hp = get_max_hp()
	_refresh_lifecycle_state()


func get_max_hp() -> int:
	if max_hp_override >= 0:
		return max(max_hp_override, 0)
	if stats == null:
		return 0
	return max(stats.get_max_hp(0), 0)


func is_alive() -> bool:
	return not is_dead


func set_stats_container(container: EntityStatsContainer) -> void:
	stats = container if container != null else EntityStatsContainerScript.new()
	_refresh_lifecycle_state()


func set_status_container(container: EntityStatusContainer) -> void:
	statuses = container if container != null else EntityStatusContainerScript.new()


func set_ability_loadout(loadout: EntityAbilityLoadout) -> void:
	abilities = loadout if loadout != null else EntityAbilityLoadoutScript.new()


func set_dice_loadout(loadout: EntityDiceLoadout) -> void:
	dice_loadout = loadout if loadout != null else EntityDiceLoadoutScript.new()


func has_tag(tag: StringName) -> bool:
	return tags.has(String(tag))


func add_tag(tag: StringName) -> void:
	if tag == StringName():
		return
	if not has_tag(tag):
		tags.append(String(tag))


func mark_dead() -> void:
	is_dead = true
	current_hp = 0


func revive(restored_hp: int) -> void:
	current_hp = max(restored_hp, 0)
	_refresh_lifecycle_state()


func _refresh_lifecycle_state() -> void:
	if current_hp > get_max_hp() and get_max_hp() >= 0:
		current_hp = get_max_hp()
	is_dead = current_hp <= 0
