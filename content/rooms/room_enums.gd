extends RefCounted
class_name RoomEnums

enum RoomType {
	UNKNOWN,
	BATTLE,
	EVENT,
	SHOP,
	ELITE_BATTLE,
	BOSS_BATTLE,
	TREASURE,
	REST,
	SPECIAL,
	SCRIPTED,
}

enum RoomStatus {
	CREATED,
	PREPARED,
	ENTERED,
	ACTIVE,
	RESOLVING,
	COMPLETED,
	FAILED,
	ABANDONED,
}

const ROOM_TYPE_TAGS := {
	RoomType.UNKNOWN: "unknown",
	RoomType.BATTLE: "battle",
	RoomType.EVENT: "event",
	RoomType.SHOP: "shop",
	RoomType.ELITE_BATTLE: "elite_battle",
	RoomType.BOSS_BATTLE: "boss_battle",
	RoomType.TREASURE: "treasure",
	RoomType.REST: "rest",
	RoomType.SPECIAL: "special",
	RoomType.SCRIPTED: "scripted",
}

const ROOM_STATUS_TAGS := {
	RoomStatus.CREATED: "created",
	RoomStatus.PREPARED: "prepared",
	RoomStatus.ENTERED: "entered",
	RoomStatus.ACTIVE: "active",
	RoomStatus.RESOLVING: "resolving",
	RoomStatus.COMPLETED: "completed",
	RoomStatus.FAILED: "failed",
	RoomStatus.ABANDONED: "abandoned",
}


static func get_room_type_tag(room_type: RoomType) -> String:
	return ROOM_TYPE_TAGS.get(room_type, "unknown")


static func get_room_status_tag(room_status: RoomStatus) -> String:
	return ROOM_STATUS_TAGS.get(room_status, "created")
