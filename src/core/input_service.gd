extends Node
signal device_family_changed(family: StringName)
var device_family: StringName = &"keyboard_mouse"
var deadzone := 0.18
var _last_aim := Vector2.RIGHT
var _previous_held := 0
var _ignore_until_next_input := false

const ControlFrameValue = preload("res://src/domain/control_frame.gd")

func note_gamepad_input() -> void:
	if device_family != &"gamepad": device_family = &"gamepad"; device_family_changed.emit(device_family)

func note_keyboard_mouse_input() -> void:
	if device_family != &"keyboard_mouse": device_family = &"keyboard_mouse"; device_family_changed.emit(device_family)

func clear_after_focus_loss() -> void:
	_previous_held = 0
	_ignore_until_next_input = true

func frame_from_actions(mouse_aim: Vector2, physics_frame: int) -> Variant:
	var frame := ControlFrameValue.new()
	var move := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", deadzone)
	var has_gamepad_aim := stick.length() >= deadzone
	if has_gamepad_aim:
		note_gamepad_input(); _last_aim = stick.normalized()
	elif mouse_aim.length() > 0.001:
		note_keyboard_mouse_input(); _last_aim = mouse_aim.normalized()
	var held := 0
	var pairs := [[&"drill", 1], [&"use_tool", 2], [&"boost", 4], [&"sonar", 8], [&"place_beacon", 16], [&"recall", 32], [&"pause", 64]]
	for pair in pairs:
		if Input.is_action_pressed(pair[0]): held |= pair[1]
	if _ignore_until_next_input:
		if held == 0 and move.length_squared() == 0.0: return frame
		_ignore_until_next_input = false
	frame.move = move
	frame.aim = _last_aim
	frame.held = held
	frame.pressed = held & ~_previous_held
	frame.released = _previous_held & ~held
	frame.device_family = device_family
	frame.physics_frame = physics_frame
	_previous_held = held
	return frame

func rebind_conflict(existing_action: StringName, target_action: StringName) -> bool:
	return existing_action != target_action and not existing_action.is_empty()
