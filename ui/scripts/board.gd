extends Node3D

@onready var dice: DiceCube3D = $dice

func _ready() -> void:
	dice.roll()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		dice.roll()
