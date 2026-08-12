class_name InputPrompt extends Control

# A compact pixel prompt strip. It deliberately consumes the existing
# InputService device-family signal instead of inspecting input events itself.
var device_family: StringName = &"keyboard_mouse"

const KEYBOARD_COPY := "LMB 钻探  ·  RMB 爆破钉  ·  Q 声呐  ·  E 信标  ·  长按 F 撤离"
const GAMEPAD_COPY := "RT 钻探  ·  LT 爆破钉  ·  X 声呐  ·  Y 信标  ·  长按 B 撤离"

func _ready() -> void:
	device_family = InputService.device_family
	InputService.device_family_changed.connect(set_device_family)
	queue_redraw()

func set_device_family(family: StringName) -> void:
	if family == device_family: return
	device_family = family
	queue_redraw()

func _draw() -> void:
	var is_gamepad := device_family == &"gamepad"
	var accent := Color("73d1c8") if is_gamepad else Color("d69a55")
	var title := "手柄控制" if is_gamepad else "键鼠控制"
	var copy := GAMEPAD_COPY if is_gamepad else KEYBOARD_COPY
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1420d9"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("3b6077"), false, 1.0)
	_draw_device_icon(is_gamepad, accent)
	draw_string(font, Vector2(25, 9), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, accent)
	draw_string(font, Vector2(25, 19), copy, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("dce8e9"))

func _draw_device_icon(is_gamepad: bool, accent: Color) -> void:
	if is_gamepad:
		draw_rect(Rect2(4, 4, 16, 10), accent, false, 1.5)
		draw_circle(Vector2(8, 9), 2.0, accent, false, 1.0)
		draw_circle(Vector2(16, 8), 1.5, accent)
		draw_circle(Vector2(18, 11), 1.5, accent)
	else:
		draw_rect(Rect2(7, 2, 10, 15), accent, false, 1.5)
		draw_line(Vector2(12, 2), Vector2(12, 9), accent, 1.0)
		draw_circle(Vector2(12, 12), 1.3, accent)
