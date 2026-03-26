extends RefCounted
class_name GlobalMapFadeTransitionPresenter


func fade_in(color_rect: ColorRect, duration: float) -> void:
	if color_rect == null:
		return
	color_rect.visible = true
	var tween := color_rect.create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished
