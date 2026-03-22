extends RefCounted
class_name BattleCombatant

const BattleEnums = preload("res://content/combat/resources/battle_enums.gd")

var combatant_id := ""
var display_name := ""
var side: BattleEnums.Side = BattleEnums.Side.PLAYER
var is_player_controlled := false
var max_hp := 0
var current_hp := 0
var armor := 0
var dice_count := 0
var dice_loadout: Array[DiceDefinition] = []
var abilities: Array[AbilityDefinition] = []
var sprite: Texture2D
var spawn_index := 0
var metadata: Dictionary = {}


func is_alive() -> bool:
	return current_hp > 0


func get_available_dice_count() -> int:
	if not dice_loadout.is_empty():
		return dice_loadout.size()
	return maxi(dice_count, 0)


func take_damage(amount: int) -> int:
	var incoming_damage := maxi(amount, 0)
	var blocked_damage := mini(armor, incoming_damage)
	armor -= blocked_damage
	var hp_damage := incoming_damage - blocked_damage
	current_hp = maxi(current_hp - hp_damage, 0)
	return hp_damage


func heal(amount: int) -> int:
	var resolved_amount := maxi(amount, 0)
	var previous_hp := current_hp
	current_hp = mini(current_hp + resolved_amount, max_hp)
	return current_hp - previous_hp


static func from_player(player: Player, sprite_texture: Texture2D, next_spawn_index: int = 0) -> BattleCombatant:
	var combatant := BattleCombatant.new()
	combatant.combatant_id = player.player_id if player != null else "player"
	combatant.display_name = player.base_stat.display_name if player != null and player.base_stat != null else "Player"
	combatant.side = BattleEnums.Side.PLAYER
	combatant.is_player_controlled = true
	combatant.max_hp = player.base_stat.max_hp if player != null and player.base_stat != null else 0
	combatant.current_hp = player.current_hp if player != null else 0
	combatant.armor = player.current_armor if player != null else 0
	combatant.dice_loadout = player.dice_loadout.duplicate() if player != null else []
	combatant.dice_count = combatant.dice_loadout.size()
	combatant.abilities = player.ability_loadout.duplicate() if player != null else []
	combatant.sprite = sprite_texture
	combatant.spawn_index = next_spawn_index
	combatant.metadata = player.metadata.duplicate(true) if player != null else {}
	return combatant


static func from_monster(definition: MonsterDefinition, next_spawn_index: int = 0) -> BattleCombatant:
	var combatant := BattleCombatant.new()
	combatant.combatant_id = definition.monster_id if definition != null else "monster"
	combatant.display_name = definition.display_name if definition != null else "Monster"
	combatant.side = BattleEnums.Side.ENEMY
	combatant.is_player_controlled = false
	combatant.max_hp = definition.max_health if definition != null else 0
	combatant.current_hp = combatant.max_hp
	combatant.dice_count = definition.dice_count if definition != null else 0
	combatant.abilities = definition.abilities.duplicate() if definition != null else []
	combatant.sprite = definition.sprite if definition != null else null
	combatant.spawn_index = next_spawn_index
	combatant.metadata = {
		"definition_id": definition.monster_id if definition != null else "",
	}
	return combatant
