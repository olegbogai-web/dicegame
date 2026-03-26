@tool
extends Resource
class_name GlobalMapDiceProfile

const DEFAULT_DICE_COUNT := 2
const DEFAULT_DICE_SKIN := preload("res://assets/dice_edges/bones_dice_skin.png")
const DEFAULT_MOB_ICON := preload("res://assets/global_map/swords.png")
const DEFAULT_EVENT_ICON := preload("res://assets/global_map/question_mark.png")

@export_range(0, 12, 1) var dice_count := DEFAULT_DICE_COUNT
@export var dice_skin: Texture2D = DEFAULT_DICE_SKIN
@export var mob_face_icon: Texture2D = DEFAULT_MOB_ICON
@export var event_face_icon: Texture2D = DEFAULT_EVENT_ICON
@export_range(0, 6, 1) var mob_face_count := 5
@export_range(0, 6, 1) var event_face_count := 1


func duplicate_profile() -> GlobalMapDiceProfile:
	var profile := GlobalMapDiceProfile.new()
	profile.dice_count = dice_count
	profile.dice_skin = dice_skin
	profile.mob_face_icon = mob_face_icon
	profile.event_face_icon = event_face_icon
	profile.mob_face_count = mob_face_count
	profile.event_face_count = event_face_count
	return profile


func get_total_face_count() -> int:
	return maxi(mob_face_count, 0) + maxi(event_face_count, 0)


func is_valid_profile() -> bool:
	return dice_count >= 0 and get_total_face_count() == 6 and mob_face_icon != null and event_face_icon != null
