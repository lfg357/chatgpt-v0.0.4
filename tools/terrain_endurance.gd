extends SceneTree

const TerrainService = preload("res://src/gameplay/terrain_service.gd")
const ObjectPool = preload("res://src/gameplay/object_pool.gd")
const DURATION_SECONDS := 600.0
const TICK_SECONDS := 1.0 / 60.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var terrain := TerrainService.new()
	terrain.setup(256, 256)
	var particles := ObjectPool.new()
	particles.warm(200)
	var removed := 0
	var frames := 0
	var delete_cursor := 0
	var end_usec := Time.get_ticks_usec() + int(DURATION_SECONDS * 1_000_000.0)
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
	var ok := terrain.dirty_chunks.is_empty() and particles.active.is_empty() and removed >= 23_800
	print("ENDURANCE seconds=%.1f frames=%d removed=%d rebuilds=%d pool_available=%d status=%s" % [DURATION_SECONDS, frames, removed, terrain.total_rebuilds, particles.available.size(), "pass" if ok else "fail"])
	quit(0 if ok else 1)
