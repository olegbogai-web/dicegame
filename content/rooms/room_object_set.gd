extends RefCounted
class_name RoomObjectSet

var objects: Array[RoomObjectInstance] = []


func add_object(room_object: RoomObjectInstance) -> void:
	if room_object == null:
		return
	objects.append(room_object)


func get_objects() -> Array[RoomObjectInstance]:
	return objects.duplicate()


func has_object(object_id: String) -> bool:
	for room_object in objects:
		if room_object != null and room_object.object_id == object_id:
			return true
	return false
