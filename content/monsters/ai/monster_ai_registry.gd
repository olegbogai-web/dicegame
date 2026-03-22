extends RefCounted
class_name MonsterAiRegistry

const BaseMonsterAiScript = preload("res://content/monsters/ai/base_monster_ai.gd")
const TestMonsterAiScript = preload("res://content/monsters/ai/test_monster_ai.gd")

static var _ai_cache: Dictionary = {}


static func get_ai(monster_id: StringName) -> BaseMonsterAi:
	if _ai_cache.has(monster_id):
		return _ai_cache[monster_id] as BaseMonsterAi

	var resolved_ai: BaseMonsterAi = _build_ai(monster_id)
	_ai_cache[monster_id] = resolved_ai
	return resolved_ai


static func _build_ai(monster_id: StringName) -> BaseMonsterAi:
	match monster_id:
		&"test_monster":
			return TestMonsterAiScript.new()
		_:
			return BaseMonsterAiScript.new()
