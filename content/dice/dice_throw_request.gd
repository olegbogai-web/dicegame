extends RefCounted
class_name DiceThrowRequest

var dice_scene: PackedScene
var size: Vector3 = Vector3.ZERO
var mass: float = 1.0
var extra_size_multiplier: Vector3 = Vector3.ONE
var metadata: Dictionary = {}


static func create(
	scene: PackedScene,
	dice_size: Vector3 = Vector3.ZERO,
	dice_mass: float = 1.0,
	extra_size: Vector3 = Vector3.ONE,
	extra_metadata: Dictionary = {}
) -> DiceThrowRequest:
	var request := DiceThrowRequest.new()
	request.dice_scene = scene
	request.size = dice_size
	request.mass = dice_mass
	request.extra_size_multiplier = extra_size
	request.metadata = extra_metadata.duplicate(true)
	return request
