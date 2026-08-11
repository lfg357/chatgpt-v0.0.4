extends SceneTree

const TerrainService = preload("res://src/gameplay/terrain_service.gd")
const ObjectPool = preload("res://src/gameplay/object_pool.gd")
const EffectPools = preload("res://src/gameplay/effect_pools.gd")
var warmup_seconds := 10.0
var sample_seconds := 120.0
const ACTIVE_TILES := 500
const TICK_SECONDS := 1.0 / 60.0

var terrain := TerrainService.new()
var particles := EffectPools.new()
var environment := ObjectPool.new()
var frame_times: Array[float] = []
var work_times: Array[float] = []
var rebuild_peak_ms := 0.0
var memory_start_mb := 0.0
var delete_cursor := 0

func _init() -> void:
	if "--quick" in OS.get_cmdline_user_args():
		warmup_seconds = 0.1
		sample_seconds = 1.0
	call_deferred("_run")

func _run() -> void:
	terrain.setup(64, 64)
	terrain.cells.fill(0)
	for index in ACTIVE_TILES:
		terrain.restore_solid(Vector2i(index % 64, index / 64))
	particles.warm_all(50)
	environment.warm(20)
	# Keep collision construction out of the sampled interval.
	while not terrain.dirty_chunks.is_empty(): terrain.physics_tick()
	await _run_interval(warmup_seconds, false)
	memory_start_mb = _memory_mb()
	await _run_interval(sample_seconds, true)
	_write_report()
	quit(0)

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

func _write_report() -> void:
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
		"mode": "headless current-development-machine"
	}
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/m1_performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))

func _memory_mb() -> float:
	return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)
