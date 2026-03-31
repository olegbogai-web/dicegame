extends RefCounted
class_name GlobalMapDiceEvolutionService

const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")

const EVENT_FACE_TAG := "question_mark"
const MOB_FACE_TAG := "swords"
const ELITE_FACE_TAG := "elite_mob"
const SHOP_FACE_TAG := "shop"
const BOSS_FACE_TAG := "boss"
const EVOLUTION_TO_EVENT_CHANCE := 0.2

const _FACE_EVOLUTION_RULES := {
	EVENT_FACE_TAG: MOB_FACE_TAG,
	MOB_FACE_TAG: ELITE_FACE_TAG,
	ELITE_FACE_TAG: SHOP_FACE_TAG,
	SHOP_FACE_TAG: BOSS_FACE_TAG,
}

const _FACE_TAG_ALIASES := {
	"event": EVENT_FACE_TAG,
	"mob": MOB_FACE_TAG,
	"elite": ELITE_FACE_TAG,
}

const _FACE_ICONS := {
	EVENT_FACE_TAG: preload("res://assets/global_map/question_mark.png"),
	MOB_FACE_TAG: preload("res://assets/global_map/swords.png"),
	ELITE_FACE_TAG: preload("res://assets/global_map/elit_mob.png"),
	SHOP_FACE_TAG: preload("res://assets/global_map/shop.png"),
	BOSS_FACE_TAG: preload("res://assets/global_map/boss.png"),
}


func evolve_all_global_map_dice(
	global_map_dice: Array[DiceDefinition],
	completed_room_face_tag: String,
	rng: RandomNumberGenerator
) -> void:
	if global_map_dice.is_empty():
		return
	var normalized_source_tag := _normalize_tag(completed_room_face_tag)
	if normalized_source_tag.is_empty():
		return
	var evolved_tag := _resolve_evolved_tag(normalized_source_tag, rng)
	for dice_definition in global_map_dice:
		_replace_single_face(dice_definition, normalized_source_tag, evolved_tag)


func _resolve_evolved_tag(source_tag: String, rng: RandomNumberGenerator) -> String:
	if not _FACE_EVOLUTION_RULES.has(source_tag):
		return source_tag
	var should_spawn_event := rng != null and rng.randf() < EVOLUTION_TO_EVENT_CHANCE
	if should_spawn_event:
		return EVENT_FACE_TAG
	return String(_FACE_EVOLUTION_RULES[source_tag])


func _replace_single_face(dice_definition: DiceDefinition, source_tag: String, target_tag: String) -> void:
	if dice_definition == null or source_tag.is_empty() or target_tag.is_empty():
		return
	for face in dice_definition.faces:
		if face == null:
			continue
		if _normalize_tag(face.text_value) != source_tag:
			continue
		_apply_face_visual(face, target_tag)
		return


func _apply_face_visual(face: DiceFaceDefinition, face_tag: String) -> void:
	face.text_value = face_tag
	face.content_type = DiceFaceDefinitionScript.ContentType.ICON
	face.icon = _FACE_ICONS.get(face_tag, _FACE_ICONS.get(EVENT_FACE_TAG))
	face.overlay_tint = Color(1.0, 1.0, 1.0, 1.0)


func _normalize_tag(raw_tag: String) -> String:
	var normalized := raw_tag.strip_edges().to_lower()
	if _FACE_TAG_ALIASES.has(normalized):
		return String(_FACE_TAG_ALIASES[normalized])
	return normalized
