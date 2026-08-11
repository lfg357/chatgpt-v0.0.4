extends Node
const PATHS := {AppState.AppMode.MAIN_MENU: "res://scenes/ui/main_menu.tscn", AppState.AppMode.PROFILE_SELECT: "res://scenes/ui/profile_select.tscn", AppState.AppMode.HUB: "res://scenes/hub/hub.tscn", AppState.AppMode.DIVE: "res://scenes/dive/dive.tscn", AppState.AppMode.RESULTS: "res://scenes/ui/results.tscn"}
func go_to(mode: AppState.AppMode) -> Result:
	var result := AppState.request_transition(mode)
	if not result.ok: return result
	if PATHS.has(mode): call_deferred("_change_scene", PATHS[mode])
	return Result.success()

func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
