extends RefCounted
class_name GlobalMapFadeTransitionPresenter

const FADE_DURATION := 0.5

var _owner: Node
var _overlay_layer: CanvasLayer
var _overlay_rect: ColorRect


func configure(owner: Node) -> void:
	_owner = owner
	if _owner == null:
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_owner.add_child(_overlay_layer)

	_overlay_rect = ColorRect.new()
	_overlay_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_overlay_rect)


func play_fade_out() -> Signal:
	if _owner == null:
		return Signal()
	if _overlay_rect == null:
		return _owner.get_tree().process_frame
	var tween := _owner.create_tween()
	tween.tween_property(_overlay_rect, "color:a", 1.0, FADE_DURATION)
	return tween.finished
