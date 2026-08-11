extends Control
@export var title_key: String = ""
@export var next_mode: AppState.AppMode = AppState.AppMode.HUB
func _ready() -> void:
	$Panel/Title.text = tr(title_key)
	$Panel/Continue.pressed.connect(func(): SceneRouter.go_to(next_mode))
