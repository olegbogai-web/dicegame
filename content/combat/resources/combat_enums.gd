extends RefCounted
class_name CombatEnums

enum Side {
	PLAYER,
	ENEMY,
}

enum BattlePhase {
	SETUP,
	TURN_START,
	DECISION,
	RESOLUTION,
	TURN_END,
	FINISHED,
}

enum BattleOutcome {
	NONE,
	PLAYER_VICTORY,
	PLAYER_DEFEAT,
	CANCELLED,
}

enum TurnEndReason {
	MANUAL,
	NO_ACTIONS_LEFT,
	AI_COMPLETED,
	BATTLE_FINISHED,
}
