extends Control
const AppStateDefinition = preload("res://src/core/app_state.gd")
@export var title_key: String = ""
@export var next_mode: AppStateDefinition.AppMode = AppStateDefinition.AppMode.HUB

const SCREEN_COPY := {
	"menu.title": ["menu.kicker", "menu.subtitle", "menu.continue", "menu.status"],
	"profile.title": ["profile.kicker", "profile.subtitle", "profile.continue", "profile.status"],
	"hub.title": ["hub.kicker", "hub.subtitle", "hub.continue", "hub.status"]
}

func _ready() -> void:
	_build_terminal_screen()
	$Panel/Continue.pressed.connect(func(): SceneRouter.go_to(next_mode))
	queue_redraw()

func _build_terminal_screen() -> void:
	var copy: Array = SCREEN_COPY.get(title_key, [title_key, title_key, title_key, title_key])
	var panel: VBoxContainer = $Panel
	panel.position = Vector2(116, 76)
	panel.size = Vector2(408, 218)
	panel.add_theme_constant_override("separation", 12)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101a29e8")
	panel_style.border_color = Color("4c7188")
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", panel_style)
	var kicker := _make_label(tr(copy[0]), 10, Color("d69a55"))
	panel.add_child(kicker)
	panel.move_child(kicker, 0)
	var title: Label = $Panel/Title
	title.text = tr(title_key)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("edf4f2"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var subtitle := _make_label(tr(copy[1]), 11, Color("8eabb8"))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size.y = 38
	panel.add_child(subtitle)
	panel.move_child(subtitle, 2)
	var button: Button = $Panel/Continue
	button.text = tr(copy[2])
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("fff0c1"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("26374b")
	normal.border_color = Color("c98a4d")
	normal.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("354f63")
	hover.border_color = Color("f0bd6d")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var status := _make_label(tr(copy[3]), 9, Color("69c8b4"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(status)

func _make_label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("080f1a"))
	# Archive-terminal frame shared by menu, profile and hub.
	draw_rect(Rect2(16, 14, size.x - 32, size.y - 28), Color("142236"), false, 2.0)
	draw_line(Vector2(32, 48), Vector2(size.x - 32, 48), Color("34566d"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(32, 37), "TSD // ARCHIVE TERMINAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("7898a7"))
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 174, 37), "LINK  STABLE  •  M3", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("67c8b4"))
	for x in range(34, int(size.x) - 34, 28):
		draw_rect(Rect2(x, size.y - 32, 14, 3), Color("263f53"))
	draw_circle(Vector2(44, 65), 4, Color("d69a55"))
	draw_circle(Vector2(58, 65), 4, Color("4f7185"))
	draw_rect(Rect2(108, 68, 424, 234), Color("0d1725e8"))
	draw_rect(Rect2(108, 68, 424, 234), Color("4c7188"), false, 2.0)
