extends Node
signal device_family_changed(family: StringName)
var device_family: StringName = &"keyboard_mouse"
func note_gamepad_input() -> void:
	if device_family != &"gamepad": device_family = &"gamepad"; device_family_changed.emit(device_family)
