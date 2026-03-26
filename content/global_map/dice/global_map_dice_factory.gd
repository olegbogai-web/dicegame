extends RefCounted
class_name GlobalMapDiceFactory

const DiceDefinitionScript = preload("res://content/dice/resources/dice_definition.gd")
const DiceFaceDefinitionScript = preload("res://content/dice/resources/dice_face_definition.gd")
const GlobalMapDiceProfile = preload("res://content/global_map/dice/global_map_dice_profile.gd")


static func build_dice_definitions(profile: GlobalMapDiceProfile) -> Array[DiceDefinition]:
	var resolved_profile := profile if profile != null else GlobalMapDiceProfile.new()
	var count := maxi(resolved_profile.dice_count, 0)
	var definitions: Array[DiceDefinition] = []
	for index in count:
		definitions.append(_build_single_definition(resolved_profile, index))
	return definitions


static func _build_single_definition(profile: GlobalMapDiceProfile, index: int) -> DiceDefinition:
	var definition := DiceDefinitionScript.new()
	definition.dice_name = "global_map_dice_%d" % index
	definition.base_color = Color(0.96, 0.96, 0.96, 1.0)
	definition.texture = profile.dice_skin
	definition.faces = _build_faces(profile)
	return definition


static func _build_faces(profile: GlobalMapDiceProfile) -> Array[DiceFaceDefinition]:
	var faces: Array[DiceFaceDefinition] = []
	for _mob_face_index in maxi(profile.mob_face_count, 0):
		faces.append(_create_icon_face("mob", profile.mob_face_icon))
	for _event_face_index in maxi(profile.event_face_count, 0):
		faces.append(_create_icon_face("event", profile.event_face_icon))
	while faces.size() < DiceDefinitionScript.FACE_COUNT:
		faces.append(_create_icon_face("mob", profile.mob_face_icon))
	if faces.size() > DiceDefinitionScript.FACE_COUNT:
		faces = faces.slice(0, DiceDefinitionScript.FACE_COUNT)
	return faces


static func _create_icon_face(text_value: String, icon: Texture2D) -> DiceFaceDefinition:
	var face := DiceFaceDefinitionScript.new()
	face.text_value = text_value
	face.content_type = DiceFaceDefinitionScript.ContentType.ICON
	face.icon = icon
	face.overlay_tint = Color(1.0, 1.0, 1.0, 1.0)
	return face
