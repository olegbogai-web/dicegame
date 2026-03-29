@tool
extends Resource
class_name AbilityCost

# Explicit ability cost container. Supports dice, actions, health and
# future currencies without changing the AbilityDefinition schema.

@export var action_points := 0
@export var mana := 0
@export var health := 0
@export var exhaust_on_use := false
@export var consume_turn := true
@export var dice_conditions: Array[AbilityDiceCondition] = []
@export var additional_costs: Dictionary = {}


func requires_dice() -> bool:
	if dice_conditions.size() > 0:
		return true
	return additional_costs.has("required_dice_sum")


func has_any_cost() -> bool:
	return action_points > 0 or mana > 0 or health > 0 or exhaust_on_use or requires_dice() or additional_costs.size() > 0
