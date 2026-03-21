extends RefCounted
class_name EntityStatsContainer

const MAX_HP_STAT: StringName = &"max_hp"

var _stats: Dictionary = {}


func set_stat(stat_id: StringName, value: float) -> void:
	if stat_id == StringName():
		return
	_stats[stat_id] = value


func get_stat(stat_id: StringName, default_value: float = 0.0) -> float:
	return float(_stats.get(stat_id, default_value))


func has_stat(stat_id: StringName) -> bool:
	return _stats.has(stat_id)


func remove_stat(stat_id: StringName) -> void:
	_stats.erase(stat_id)


func clear() -> void:
	_stats.clear()


func get_all_stats() -> Dictionary:
	return _stats.duplicate(true)


func set_stats(stats: Dictionary) -> void:
	_stats = {}
	for stat_id in stats.keys():
		if stat_id is StringName:
			_stats[stat_id] = float(stats[stat_id])
		elif stat_id is String:
			_stats[StringName(stat_id)] = float(stats[stat_id])


func get_max_hp(default_value: int = 0) -> int:
	return int(round(get_stat(MAX_HP_STAT, default_value)))
