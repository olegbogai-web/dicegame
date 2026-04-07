@tool
extends Resource
class_name AbilityDefinition

const DEFAULT_UPGRADE_LEVELS := 3

enum Kind {
	ACTIVE,
	PASSIVE,
	REACTION,
}

enum OwnerScope {
	PLAYER,
	MONSTER,
	ANY,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	UNIQUE,
}

const KIND_TAGS := {
	Kind.ACTIVE: "active",
	Kind.PASSIVE: "passive",
	Kind.REACTION: "reaction",
}

const OWNER_SCOPE_TAGS := {
	OwnerScope.PLAYER: "player",
	OwnerScope.MONSTER: "monster",
	OwnerScope.ANY: "any_owner",
}

@export_category("Identity")
@export var ability_id := ""
@export var display_name := "New Ability"
@export_multiline var description := ""
@export_multiline var flavor_text := ""
@export var icon: Texture2D
@export var sprite_scale: Vector2 = Vector2.ONE
@export var tags: PackedStringArray = PackedStringArray()
@export var kind: Kind = Kind.ACTIVE
@export var owner_scope: OwnerScope = OwnerScope.ANY
@export var rarity: Rarity = Rarity.COMMON

@export_category("Availability")
@export_range(0, 99, 1) var unlock_level := 0
@export_range(0, 99, 1) var upgrade_level := 0
@export_range(0, 99, 1) var max_upgrade_level := DEFAULT_UPGRADE_LEVELS
@export_range(0, 99, 1) var cooldown_turns := 0
@export_range(0, 99, 1) var charges := 0
@export var starts_on_cooldown := false
@export var once_per_battle := false
@export_range(0, 99, 1) var max_uses_per_battle := 0
@export_range(0, 99, 1) var max_uses_per_turn := 0
@export var exhausts_for_battle := false

@export_category("Rules")
@export var cost: AbilityCost
@export var target_rule: AbilityTargetRule
@export var cast_conditions: Array[AbilityCondition] = []
@export var use_conditions: Array[AbilityCondition] = []
@export var effects: Array[AbilityEffectDefinition] = []
@export var follow_up_ability_ids: PackedStringArray = PackedStringArray()
@export var ai_hints: Dictionary = {}
@export var ui_metadata: Dictionary = {}


func _init() -> void:
	if cost == null:
		cost = AbilityCost.new()
	if target_rule == null:
		target_rule = AbilityTargetRule.new()


func is_active() -> bool:
	return kind == Kind.ACTIVE


func is_passive() -> bool:
	return kind == Kind.PASSIVE


func supports_owner(is_player_owner: bool) -> bool:
	if owner_scope == OwnerScope.ANY:
		return true
	return is_player_owner and owner_scope == OwnerScope.PLAYER or (not is_player_owner and owner_scope == OwnerScope.MONSTER)


func has_dice_interaction() -> bool:
	if cost != null and cost.requires_dice():
		return true
	for effect in effects:
		if effect != null and (effect.dice_query_tags.size() > 0 or effect.duplicates_dice_selection()):
			return true
	return false


func is_valid_definition() -> bool:
	if ability_id.is_empty() or display_name.is_empty():
		return false
	if max_upgrade_level < upgrade_level:
		return false
	if cost == null or target_rule == null:
		return false
	for condition in cast_conditions:
		if condition == null or not condition.is_valid_definition():
			return false
	for condition in use_conditions:
		if condition == null or not condition.is_valid_definition():
			return false
	for effect in effects:
		if effect == null or not effect.is_valid_definition():
			return false
	return true


func get_all_tags() -> PackedStringArray:
	var resolved_tags := PackedStringArray(tags)
	resolved_tags.append(ability_id)
	resolved_tags.append(KIND_TAGS.get(kind, "unknown_kind"))
	resolved_tags.append(OWNER_SCOPE_TAGS.get(owner_scope, "unknown_owner"))
	return resolved_tags


func get_sprite_size(base_size: Vector2) -> Vector2:
	return Vector2(base_size.x * sprite_scale.x, base_size.y * sprite_scale.y)
