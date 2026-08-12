class_name ControlFrame extends RefCounted

enum Action { DRILL = 1, TOOL = 2, BOOST = 4, SONAR = 8, BEACON = 16, RECALL = 32, PAUSE = 64 }

var move: Vector2 = Vector2.ZERO
var aim: Vector2 = Vector2.RIGHT
var pressed: int = 0
var held: int = 0
var released: int = 0
var device_family: StringName = &"keyboard_mouse"
var physics_frame: int = 0

func has_held(button: int) -> bool:
	return (held & button) != 0

func has_pressed(button: int) -> bool:
	return (pressed & button) != 0
