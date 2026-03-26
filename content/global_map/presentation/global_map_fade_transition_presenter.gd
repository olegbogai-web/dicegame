extends RefCounted
class_name GlobalMapFadeTransitionPresenter

const FADE_DURATION := 0.45

var _fade_rect: ColorRect


func setup(fade_rect: ColorRect) -> void:
	_fade_rect = fade_rect
	if _fade_rect != null:
		_fade_rect.visible = false
		_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)


func play_fade_to_black(owner: Node) -> void:
	if owner == null or _fade_rect == null:
		return
	_fade_rect.visible = true
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	var tween := owner.create_tween()
	tween.tween_property(_fade_rect, "color", Color(0.0, 0.0, 0.0, 1.0), FADE_DURATION)
	await tween.finished
