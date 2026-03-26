extends RefCounted
class_name GlobalMapFadeTransitionPresenter


func fade_in_out(fade_rect: ColorRect, duration: float) -> void:
	if fade_rect == null:
		return

	fade_rect.visible = true
	var total_duration := maxf(duration, 0.01)
	var fade_tween := fade_rect.create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, total_duration)
	await fade_tween.finished
