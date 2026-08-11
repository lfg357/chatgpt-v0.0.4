extends SceneTree

const TerrainService = preload("res://src/gameplay/terrain_service.gd")
const ObjectPool = preload("res://src/gameplay/object_pool.gd")
const FULL_DURATION_SECONDS := 1800.0
const QUICK_DURATION_SECONDS := 10.0
const TICK_SECONDS := 1.0 / 60.0

var duration_seconds := FULL_DURATION_SECONDS
var force_over_memory := false

func _init() -> void:
	if "--quick" in OS.get_cmdline_user_args(): duration_seconds = QUICK_DURATION_SECONDS
	if "--force-over-memory" in OS.get_cmdline_user_args():
		duration_seconds = 0.1
		force_over_memory = true
	call_deferred("_run")

func _run() -> void:
	var terrain := TerrainService.new()
	terrain.setup(256, 256)
	var particles := ObjectPool.new()
	particles.warm(200)
	var baseline_mb := _memory_mb()
	var removed := 0
	var frames := 0
	var delete_cursor := 0
	var end_usec := Time.get_ticks_usec() + int(duration_seconds * 1_000_000.0)
	var next_delete_usec := Time.get_ticks_usec() + 1_000_000
	while Time.get_ticks_usec() < end_usec:
		await create_timer(TICK_SECONDS).timeout
		frames += 1
		var now_usec := Time.get_ticks_usec()
		while now_usec >= next_delete_usec:
			for _i in 40:
				terrain.request_damage(Vector2i(delete_cursor % 256, delete_cursor / 256))
				delete_cursor += 1
			next_delete_usec += 1_000_000
		removed += terrain.commit_damage()
		terrain.physics_tick()
		if frames % 30 == 0:
			var particle := particles.acquire()
			particles.release(particle)
	var end_mb := _memory_mb()
	var growth_percent := 100.0 * (end_mb - baseline_mb) / maxf(0.001, baseline_mb)
	if force_over_memory: growth_percent = 999.0
	var web_budget := OS.has_feature("web")
	var limit := 15.0 if web_budget else 10.0
	var passed := terrain.dirty_chunks.is_empty() and particles.active.is_empty() and growth_percent <= limit
	var report := {"duration_seconds": duration_seconds, "frames": frames, "removed": removed, "rebuilds": terrain.total_rebuilds, "pool_available": particles.available.size(), "memory_start_mb": baseline_mb, "memory_end_mb": end_mb, "memory_growth_percent": growth_percent, "memory_growth_limit_percent": limit, "platform": "web" if web_budget else "windows", "passed": passed, "forced": force_over_memory}
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/m1_endurance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	quit(0 if passed else 1)

func _memory_mb() -> float:
	return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0)
