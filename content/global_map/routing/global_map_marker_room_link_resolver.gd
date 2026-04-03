extends RefCounted
class_name GlobalMapMarkerRoomLinkResolver

const GlobalMapDiceEvolutionService = preload("res://content/global_map/dice/global_map_dice_evolution_service.gd")
const GLOBAL_MAP_RESOLVER_LOG_PREFIX := "[GlobalMapResolve]"

const TEST_EVENT_ROOM_SCENE_PATH := "res://scenes/event_room.tscn"
const TEST_BATTLE_ROOM_SCENE_PATH := "res://scenes/new_battle_table.tscn"
const TEST_SHOP_ROOM_SCENE_PATH := "res://scenes/shop.tscn"
const EVENT_ICON := preload("res://assets/global_map/question_mark.png")
const MOB_ICON := preload("res://assets/global_map/swords.png")
const ELITE_ICON := preload("res://assets/global_map/elit_mob.png")
const SHOP_ICON := preload("res://assets/global_map/shop.png")
const BOSS_ICON := preload("res://assets/global_map/boss.png")


func resolve_marker_for_face(face: DiceFaceDefinition) -> Dictionary:
	if face == null:
		print("%s face=null -> event" % GLOBAL_MAP_RESOLVER_LOG_PREFIX)
		return _build_event_marker_data()
	var normalized_tag := face.text_value.strip_edges().to_lower()
	print("%s face=%s" % [GLOBAL_MAP_RESOLVER_LOG_PREFIX, normalized_tag])
	match normalized_tag:
		GlobalMapDiceEvolutionService.MOB_FACE_TAG:
			return _build_marker_data(TEST_BATTLE_ROOM_SCENE_PATH, MOB_ICON, GlobalMapDiceEvolutionService.MOB_FACE_TAG)
		GlobalMapDiceEvolutionService.ELITE_FACE_TAG:
			return _build_marker_data(TEST_BATTLE_ROOM_SCENE_PATH, ELITE_ICON, GlobalMapDiceEvolutionService.ELITE_FACE_TAG)
		GlobalMapDiceEvolutionService.SHOP_FACE_TAG:
			return _build_marker_data(TEST_SHOP_ROOM_SCENE_PATH, SHOP_ICON, GlobalMapDiceEvolutionService.SHOP_FACE_TAG)
		GlobalMapDiceEvolutionService.BOSS_FACE_TAG:
			return _build_marker_data(TEST_BATTLE_ROOM_SCENE_PATH, BOSS_ICON, GlobalMapDiceEvolutionService.BOSS_FACE_TAG)
		GlobalMapDiceEvolutionService.EVENT_FACE_TAG:
			return _build_event_marker_data()
		_:
			return _build_event_marker_data()


func _build_event_marker_data() -> Dictionary:
	return _build_marker_data(TEST_EVENT_ROOM_SCENE_PATH, EVENT_ICON, GlobalMapDiceEvolutionService.EVENT_FACE_TAG)


func _build_marker_data(scene_path: String, icon: Texture2D, marker_type: String) -> Dictionary:
	return {
		"scene_path": scene_path,
		"icon": icon,
		"type": marker_type,
	}
