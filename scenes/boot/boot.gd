extends Node
func _ready() -> void:
	ContentDB.load_all()
	SceneRouter.go_to(AppState.AppMode.MAIN_MENU)
