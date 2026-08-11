extends Control
const AppStateDefinition = preload("res://src/core/app_state.gd")
@export var title_key: String = ""
@export var next_mode: AppStateDefinition.AppMode = AppStateDefinition.AppMode.HUB
func _ready() -> void:
	$Panel/Title.text = tr(title_key)
	$Panel/Continue.pressed.connect(func(): SceneRouter.go_to(next_mode))
