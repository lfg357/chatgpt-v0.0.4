extends Node
const AppStateDefinition = preload("res://src/core/app_state.gd")
const ResultValue = preload("res://src/core/result.gd")
const PATHS := {AppStateDefinition.AppMode.MAIN_MENU: "res://scenes/ui/main_menu.tscn", AppStateDefinition.AppMode.PROFILE_SELECT: "res://scenes/ui/profile_select.tscn", AppStateDefinition.AppMode.HUB: "res://scenes/hub/hub.tscn", AppStateDefinition.AppMode.DIVE: "res://scenes/dive/dive.tscn", AppStateDefinition.AppMode.RESULTS: "res://scenes/ui/results.tscn"}
func go_to(mode: AppStateDefinition.AppMode) -> ResultValue:
	var result := AppState.request_transition(mode)
	if not result.ok: return result
	if PATHS.has(mode): call_deferred("_change_scene", PATHS[mode])
	return ResultValue.success()

func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
