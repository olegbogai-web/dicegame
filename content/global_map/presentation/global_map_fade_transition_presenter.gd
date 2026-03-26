extends RefCounted
class_name GlobalMapFadeTransitionPresenter

var _fade_overlay: ColorRect
var _fade_duration: float


func _init(fade_overlay: ColorRect, fade_duration: float) -> void:
	_fade_overlay = fade_overlay
	_fade_duration = fade_duration


func play_fade_to_black(owner: Node) -> void:
	if owner == null or _fade_overlay == null:
		return
	_fade_overlay.visible = true
	var tween := owner.create_tween()
	tween.tween_property(_fade_overlay, "modulate:a", 1.0, _fade_duration)
	await tween.finished
