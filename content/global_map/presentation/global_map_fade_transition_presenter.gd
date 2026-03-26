extends RefCounted
class_name GlobalMapFadeTransitionPresenter

const FADE_DURATION := 0.35


func fade_to_black(fade_rect: ColorRect) -> void:
	if fade_rect == null:
		return
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var tween := fade_rect.create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished
