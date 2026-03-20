extends Node3D

const DICE_VIEW_SCENE := preload("res://ui/scenes/dice/dice_view.tscn")
const DEFAULT_DICE := preload("res://resources/dice/default_battle_die.tres")

@onready var _dice_anchor: Node3D = $dice_anchor

func _ready() -> void:
	_spawn_demo_die()

func _spawn_demo_die() -> void:
	var dice: DiceView = DICE_VIEW_SCENE.instantiate()
	dice.dice_definition = DEFAULT_DICE
	dice.transform.origin = Vector3(0, 2.5, 0)
	_dice_anchor.add_child(dice)
	dice.apply_throw(Vector3(0.35, 0.0, 0.15), Vector3(1.6, 0.7, -1.1))
