extends Node

const ResultValue = preload("res://src/core/result.gd")

signal mode_changed(previous: AppMode, current: AppMode, payload: Dictionary)
enum AppMode { BOOT, MAIN_MENU, PROFILE_SELECT, HUB, DIVE, RESULTS, SOFT_RESET }
var mode: AppMode = AppMode.BOOT
var current_profile: int = -1

const ALLOWED := {
	AppMode.BOOT: [AppMode.MAIN_MENU],
	AppMode.MAIN_MENU: [AppMode.PROFILE_SELECT],
	AppMode.PROFILE_SELECT: [AppMode.MAIN_MENU, AppMode.HUB],
	AppMode.HUB: [AppMode.DIVE, AppMode.SOFT_RESET, AppMode.MAIN_MENU],
	AppMode.DIVE: [AppMode.RESULTS, AppMode.HUB],
	AppMode.RESULTS: [AppMode.HUB],
	AppMode.SOFT_RESET: [AppMode.HUB]
}

func request_transition(target: AppMode, payload: Dictionary = {}) -> ResultValue:
	if not ALLOWED.get(mode, []).has(target): return ResultValue.failure(&"illegal_transition", &"error.illegal_transition")
	var previous := mode
	mode = target
	mode_changed.emit(previous, mode, payload)
	return ResultValue.success()
