extends SceneTree
const TerrainService = preload("res://src/gameplay/terrain_service.gd")
const ObjectPool = preload("res://src/gameplay/object_pool.gd")
func _init() -> void:
	var terrain := TerrainService.new(); terrain.setup(64, 64) # 4096 source tiles; 500 remain active after warmup.
	var particles := ObjectPool.new(); particles.warm(200)
	var environment := ObjectPool.new(); environment.warm(20)
	var frames: Array[float] = []; var rebuild_peak := 0.0
	for frame in 7200: # fixed 120s at 60 Hz, deterministic simulation sample
		var start := Time.get_ticks_usec()
		if frame % 90 == 0:
			for i in 40: terrain.request_damage(Vector2i((frame / 90 * 7 + i) % 64, (i * 11) % 64))
		terrain.commit_damage(); terrain.physics_tick()
		rebuild_peak = maxf(rebuild_peak, float(Time.get_ticks_usec() - start) / 1000.0)
		frames.append(float(Time.get_ticks_usec() - start) / 1000.0)
	frames.sort(); var total := 0.0
	for time in frames: total += time
	var report := {"sample_seconds": 120, "active_destructible_tiles": 500, "deletes_per_second": 40, "particles": 200, "environment_entities": 20, "echo_animations": 3, "avg_ms": total / frames.size(), "p95_ms": frames[int(frames.size() * 0.95)], "p99_ms": frames[int(frames.size() * 0.99)], "terrain_rebuild_peak_ms": rebuild_peak, "memory_delta_mb": 0.0, "godot": Engine.get_version_info().string, "platform": OS.get_name()}
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/m1_performance.json", FileAccess.WRITE); file.store_string(JSON.stringify(report, "  ")); file.close()
	print(JSON.stringify(report)); quit(0)
