extends RefCounted
class_name GlobalMapEventIconPresenter

var _event_icon: Node3D


func configure(event_icon: Node3D) -> void:
	_event_icon = event_icon


func hide() -> void:
	if _event_icon == null:
		return
	_event_icon.visible = false
