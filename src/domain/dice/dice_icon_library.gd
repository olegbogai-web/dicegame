extends Resource
class_name DiceIconLibrary

@export var icons: Dictionary = {}

func get_icon(icon_id: StringName) -> Texture2D:
	if icon_id.is_empty():
		return null

	return icons.get(icon_id) as Texture2D
