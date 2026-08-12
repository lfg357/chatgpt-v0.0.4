extends Node

const ResultValue = preload("res://src/core/result.gd")
const EconomyValue = preload("res://src/domain/economy_service.gd")
const MapGeneratorValue = preload("res://src/domain/map_generator.gd")

signal mode_changed(previous: AppMode, current: AppMode, payload: Dictionary)
signal run_started(config: Resource)
signal run_completed(result: Resource, settlement: RefCounted)
enum AppMode { BOOT, MAIN_MENU, PROFILE_SELECT, HUB, DIVE, RESULTS, SOFT_RESET }
var mode: AppMode = AppMode.BOOT
var current_profile: int = -1
var current_run_config: Resource
var last_run_result: Resource
var last_settlement: RefCounted
var completed_run_ids: Dictionary = {}

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

func start_run(config: Resource) -> ResultValue:
	if config == null or config.layer_id == &"" or config.generator_version <= 0: return ResultValue.failure(&"invalid_run_config")
	if config.generator_version != MapGeneratorValue.GENERATOR_VERSION or config.content_version != MapGeneratorValue.CONTENT_VERSION: return ResultValue.failure(&"unsupported_generation_version")
	if current_run_config != null: return ResultValue.failure(&"run_already_active")
	current_run_config = config; last_run_result = null; last_settlement = null
	run_started.emit(config)
	return ResultValue.success(config)

func complete_run(result: Resource) -> RefCounted:
	if result == null or completed_run_ids.has(result.run_id): return last_settlement
	var active_snapshot = SaveService.active_snapshot
	var working_snapshot = null if active_snapshot == null else active_snapshot.from_dict(active_snapshot.to_dict().duplicate(true))
	var economy = EconomyValue.new(working_snapshot)
	var settlement = economy.apply_run_result(result)
	if not settlement.committed: return settlement
	if active_snapshot != null:
		SaveService.active_snapshot = working_snapshot
		var saved = SaveService.save_profile(working_snapshot.profile_id, &"run_settlement")
		if not saved.ok:
			SaveService.active_snapshot = active_snapshot; settlement.committed = false; settlement.error_code = &"save_failed"; return settlement
	completed_run_ids[result.run_id] = true; current_run_config = null; last_run_result = result; last_settlement = settlement
	run_completed.emit(result, settlement)
	return settlement
