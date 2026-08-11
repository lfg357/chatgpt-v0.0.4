extends Node
func _ready() -> void:
	ContentDB.load_all()
	SceneRouter.go_to(AppState.AppMode.MAIN_MENU)
	if "--scene-smoke" in OS.get_cmdline_user_args():
		get_tree().create_timer(0.1).timeout.connect(func(): get_tree().quit(0))
