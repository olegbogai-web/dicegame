extends RefCounted
class_name BattleEnums

enum Side {
	PLAYER,
	ENEMY,
}

enum Phase {
	SETUP,
	TURN_START,
	AWAITING_PLAYER_ACTION,
	RESOLVING_ACTION,
	MONSTER_TURN,
	FINISHED,
}

enum ResultType {
	NONE,
	PLAYER_VICTORY,
	PLAYER_DEFEAT,
	CANCELLED,
}
