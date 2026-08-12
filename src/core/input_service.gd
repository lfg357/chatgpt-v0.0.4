extends Node
signal device_family_changed(family: StringName)
var device_family: StringName = &"keyboard_mouse"
var deadzone := 0.18
var _last_aim := Vector2.RIGHT
var _previous_held := 0
var _ignore_until_next_input := false
var _suppressed_physics_frames := 0

const ControlFrameValue = preload("res://src/domain/control_frame.gd")

func _ready() -> void:
	_add_gamepad_defaults()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		note_gamepad_input()
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= deadzone:
		note_gamepad_input()
	elif (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		note_keyboard_mouse_input()

func note_gamepad_input() -> void:
	if device_family != &"gamepad": device_family = &"gamepad"; device_family_changed.emit(device_family)

func note_keyboard_mouse_input() -> void:
	if device_family != &"keyboard_mouse": device_family = &"keyboard_mouse"; device_family_changed.emit(device_family)

func clear_after_focus_loss() -> void:
	_previous_held = 0
	_ignore_until_next_input = true

func suppress_gameplay_for_frames(frames: int = 2) -> void:
	_suppressed_physics_frames = maxi(_suppressed_physics_frames, frames)
	_previous_held = 0

func frame_from_actions(mouse_aim: Vector2, physics_frame: int) -> Variant:
	var frame := ControlFrameValue.new()
	if _suppressed_physics_frames > 0:
		_suppressed_physics_frames -= 1
		return frame
	var move := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", deadzone)
	var has_gamepad_aim := stick.length() >= deadzone
	if has_gamepad_aim:
		note_gamepad_input(); _last_aim = stick.normalized()
	elif mouse_aim.length() > 0.001:
		note_keyboard_mouse_input(); _last_aim = mouse_aim.normalized()
	var held := 0
	var ui_has_mouse := get_viewport().gui_get_hovered_control() != null
	var pairs := [[&"drill", 1], [&"use_tool", 2], [&"boost", 4], [&"sonar", 8], [&"place_beacon", 16], [&"recall", 32], [&"pause", 64]]
	for pair in pairs:
		if Input.is_action_pressed(pair[0]) and not (ui_has_mouse and (pair[1] == 1 or pair[1] == 2)):
			held |= pair[1]
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

func _add_gamepad_defaults() -> void:
	# Xbox layout: left stick moves, right stick aims, A boosts, RT drills, LT uses tool.
	_add_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis(&"move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(&"move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis(&"aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis(&"aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_axis(&"aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_axis(&"aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_axis(&"drill", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis(&"use_tool", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_button(&"boost", JOY_BUTTON_A)
	_add_button(&"sonar", JOY_BUTTON_X)
	_add_button(&"place_beacon", JOY_BUTTON_Y)
	_add_button(&"recall", JOY_BUTTON_B)
	_add_button(&"pause", JOY_BUTTON_START)

func _add_axis(action: StringName, axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)

func _add_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
