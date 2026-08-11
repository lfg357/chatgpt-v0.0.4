extends Node
const SMOKE_SCENES := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/profile_select.tscn",
	"res://scenes/hub/hub.tscn",
	"res://scenes/dive/dive.tscn",
	"res://scenes/ui/results.tscn",
	"res://scenes/benchmarks/m1_benchmark.tscn"
]

func _ready() -> void:
	ContentDB.load_all()
	if "--scene-smoke" in OS.get_cmdline_user_args():
		for scene_path in SMOKE_SCENES:
			var packed := load(scene_path) as PackedScene
			if packed == null:
				push_error("Scene smoke load failed: " + scene_path)
				get_tree().quit(1)
				return
			var instance := packed.instantiate()
			if instance.get_script() == null:
				push_error("Scene smoke root script failed: " + scene_path)
				get_tree().quit(1)
				return
			instance.queue_free()
		print("SCENE_SMOKE passed scenes=%d" % SMOKE_SCENES.size())
		get_tree().quit(0)
		return
	SceneRouter.go_to(AppState.AppMode.MAIN_MENU)
