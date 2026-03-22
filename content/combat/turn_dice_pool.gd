extends RefCounted
class_name TurnDicePool

var owner_id: StringName = &""
var rolled_dice: Array[Dictionary] = []
var spent_die_ids: Array[StringName] = []


func configure(next_owner_id: StringName, next_rolled_dice: Array[Dictionary]) -> void:
	owner_id = next_owner_id
	set_rolled_dice(next_rolled_dice)


func set_rolled_dice(next_rolled_dice: Array[Dictionary]) -> void:
	rolled_dice.clear()
	for entry in next_rolled_dice:
		var runtime_id := StringName(entry.get("id", &""))
		if runtime_id == &"":
			continue
		rolled_dice.append(_sanitize_entry(entry))

	var available_ids := {}
	for entry in rolled_dice:
		available_ids[entry["id"]] = true

	var filtered_spent: Array[StringName] = []
	for spent_die_id in spent_die_ids:
		if available_ids.has(spent_die_id):
			filtered_spent.append(spent_die_id)
	spent_die_ids = filtered_spent


func clear() -> void:
	rolled_dice.clear()
	spent_die_ids.clear()


func get_available_dice() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for entry in rolled_dice:
		if spent_die_ids.has(entry["id"]):
			continue
		available.append(entry)
	return available


func get_die_entry(runtime_id: StringName) -> Dictionary:
	for entry in rolled_dice:
		if entry["id"] == runtime_id:
			return entry
	return {}


func are_dice_available(runtime_ids: Array[StringName]) -> bool:
	var seen := {}
	for runtime_id in runtime_ids:
		if runtime_id == &"" or seen.has(runtime_id) or spent_die_ids.has(runtime_id):
			return false
		seen[runtime_id] = true
		if get_die_entry(runtime_id).is_empty():
			return false
	return true


func spend_dice(runtime_ids: Array[StringName]) -> Array[Dictionary]:
	var spent_entries: Array[Dictionary] = []
	if not are_dice_available(runtime_ids):
		return spent_entries

	for runtime_id in runtime_ids:
		spent_die_ids.append(runtime_id)
		spent_entries.append(get_die_entry(runtime_id))
	return spent_entries


func has_available_dice() -> bool:
	return not get_available_dice().is_empty()


func _sanitize_entry(entry: Dictionary) -> Dictionary:
	return {
		"id": StringName(entry.get("id", &"")),
		"value": int(entry.get("value", -1)),
		"tags": PackedStringArray(entry.get("tags", PackedStringArray())),
		"face_id": StringName(entry.get("face_id", &"")),
	}
