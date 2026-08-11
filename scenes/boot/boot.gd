extends Node
func _ready() -> void:
	ContentDB.load_all()
	SceneRouter.go_to(AppState.AppMode.MAIN_MENU)
	if "--scene-smoke" in OS.get_cmdline_user_args(): get_tree().quit(0)
