extends RefCounted
class_name MonsterAiRegistry

const TestMonsterAiProfileScript = preload("res://content/combat/monster_ai/profiles/test_monster_ai.gd")

static var _profile_cache: Dictionary = {}


static func resolve_profile(monster_definition: MonsterDefinition) -> MonsterAiProfile:
	if monster_definition == null:
		return null
	var profile_id := _resolve_profile_id(monster_definition)
	if profile_id == &"":
		return null
	if _profile_cache.has(profile_id):
		return _profile_cache[profile_id] as MonsterAiProfile
	var profile := _build_profile(profile_id)
	if profile != null:
		_profile_cache[profile_id] = profile
	return profile


static func _resolve_profile_id(monster_definition: MonsterDefinition) -> StringName:
	if monster_definition.ai_profile_id != &"":
		return monster_definition.ai_profile_id
	return StringName(monster_definition.monster_id)


static func _build_profile(profile_id: StringName) -> MonsterAiProfile:
	match profile_id:
		&"test_monster":
			return TestMonsterAiProfileScript.new()
	return null
