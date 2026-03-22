extends RefCounted
class_name MonsterAIRegistry

const MonsterAIProfileScript = preload("res://content/monster_ai/monster_ai_profile.gd")
const TestMonsterBasicAIScript = preload("res://content/monster_ai/profiles/test_monster_basic_ai.gd")

const PROFILE_BY_ID := {
	&"test_monster_basic": TestMonsterBasicAIScript,
}


static func resolve_profile(profile_id: StringName) -> MonsterAIProfile:
	var script := PROFILE_BY_ID.get(profile_id)
	if script == null:
		return MonsterAIProfileScript.new()
	return script.new()
