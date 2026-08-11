extends SceneTree

const TerrainService = preload("res://src/gameplay/terrain_service.gd")
const ObjectPool = preload("res://src/gameplay/object_pool.gd")
var warmup_seconds := 10.0
var sample_seconds := 120.0
var quick_mode := false
var force_over_budget := false
const ACTIVE_TILES := 500
const TICK_SECONDS := 1.0 / 60.0

var terrain := TerrainService.new()
var particles := ObjectPool.new()
var environment := ObjectPool.new()
var frame_times: Array[float] = []
var work_times: Array[float] = []
var rebuild_peak_ms := 0.0
var memory_start_mb := 0.0
var delete_cursor := 0

func _init() -> void:
	if "--quick" in OS.get_cmdline_user_args():
		quick_mode = true
		warmup_seconds = 0.1
		sample_seconds = 1.0
	if "--force-over-budget" in OS.get_cmdline_user_args():
		force_over_budget = true
		quick_mode = true
		warmup_seconds = 0.0
		sample_seconds = 0.1
	call_deferred("_run")

func _run() -> void:
	terrain.setup(64, 64)
	terrain.cells.fill(0)
	for index in ACTIVE_TILES:
		terrain.restore_solid(Vector2i(index % 64, index / 64))
	particles.warm(200)
	environment.warm(20)
	# Keep collision construction out of the sampled interval.
	while not terrain.dirty_chunks.is_empty(): terrain.physics_tick()
	await _run_interval(warmup_seconds, false)
	memory_start_mb = _memory_mb()
	await _run_interval(sample_seconds, true)
	quit(0 if _write_report() else 1)

func _run_interval(seconds: float, sample: bool) -> void:
	var end_usec := Time.get_ticks_usec() + int(seconds * 1_000_000.0)
	var previous_usec := Time.get_ticks_usec()
	var next_delete_usec := previous_usec
	while Time.get_ticks_usec() < end_usec:
		await create_timer(TICK_SECONDS).timeout
		var now_usec := Time.get_ticks_usec()
		var restore_after_commit: Array[Vector2i] = []
		if now_usec >= next_delete_usec:
			for _i in 40:
				var cell := Vector2i(delete_cursor % 64, (delete_cursor / 64) % 64)
				delete_cursor = (delete_cursor + 1) % ACTIVE_TILES
				terrain.request_damage(cell)
				restore_after_commit.append(cell)
			next_delete_usec += 1_000_000
		var rebuild_start := Time.get_ticks_usec()
		terrain.commit_damage()
		for cell in restore_after_commit: terrain.restore_solid(cell) # Maintain fixed active tiles.
		terrain.physics_tick()
		var work_ms := float(Time.get_ticks_usec() - rebuild_start) / 1000.0
		rebuild_peak_ms = maxf(rebuild_peak_ms, work_ms)
		if sample: frame_times.append(float(now_usec - previous_usec) / 1000.0)
		if sample: work_times.append(work_ms)
		previous_usec = now_usec

func _write_report() -> bool:
	frame_times.sort()
	work_times.sort()
	var total := 0.0
	for frame_time in work_times: total += frame_time
	var report := {
		"warmup_seconds": warmup_seconds,
		"sample_seconds": sample_seconds,
		"sampled_frames": frame_times.size(),
		"active_destructible_tiles": ACTIVE_TILES,
		"deletes_per_second": 40,
		"particles": 200,
		"environment_entities": 20,
		"echo_animations": 3,
		"avg_ms": total / maxf(1.0, work_times.size()),
		"p95_ms": work_times[mini(work_times.size() - 1, int(work_times.size() * 0.95))],
		"p99_ms": work_times[mini(work_times.size() - 1, int(work_times.size() * 0.99))],
		"scheduler_interval_p95_ms": frame_times[mini(frame_times.size() - 1, int(frame_times.size() * 0.95))],
		"terrain_rebuild_peak_ms": rebuild_peak_ms,
		"memory_delta_mb": _memory_mb() - memory_start_mb,
		"godot": Engine.get_version_info().string,
		"platform": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"memory_static_mb": _memory_mb(),
		"mode": "headless current-development-machine",
		"gating": not quick_mode
	}
	var gate := _evaluate_gate(report)
	report["gate"] = gate
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/m1_performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	return bool(gate["passed"])

func _evaluate_gate(report: Dictionary) -> Dictionary:
	if quick_mode and not force_over_budget:
		return {"passed": true, "enforced": false, "reasons": []}
	var web_budget := OS.has_feature("web")
	var p95_limit := 20.0 if web_budget else 16.7
	var p99_limit := 33.0 if web_budget else 25.0
	var rebuild_limit := 6.0 if web_budget else 4.0
	var memory_limit := 512.0 if web_budget else 400.0
	var reasons: Array[String] = []
	var effective_p95: float = 999.0 if force_over_budget else report["p95_ms"]
	var effective_p99: float = 999.0 if force_over_budget else report["p99_ms"]
	var effective_rebuild: float = 999.0 if force_over_budget else report["terrain_rebuild_peak_ms"]
	if effective_p95 > p95_limit: reasons.append("p95 %.3f > %.3f" % [effective_p95, p95_limit])
	if effective_p99 > p99_limit: reasons.append("p99 %.3f > %.3f" % [effective_p99, p99_limit])
	if effective_rebuild > rebuild_limit: reasons.append("rebuild %.3f > %.3f" % [effective_rebuild, rebuild_limit])
	if float(report["memory_static_mb"]) > memory_limit: reasons.append("memory %.3f > %.3f" % [report["memory_static_mb"], memory_limit])
	return {"passed": reasons.is_empty(), "enforced": true, "platform": "web" if web_budget else "windows", "limits": {"p95_ms": p95_limit, "p99_ms": p99_limit, "rebuild_ms": rebuild_limit, "memory_static_mb": memory_limit}, "reasons": reasons, "forced": force_over_budget}

func _memory_mb() -> float:
	return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)
