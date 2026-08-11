extends SceneTree
const TerrainService = preload("res://src/gameplay/terrain_service.gd")
const ObjectPool = preload("res://src/gameplay/object_pool.gd")
func _init() -> void:
	var terrain := TerrainService.new(); terrain.setup(256, 256)
	var particles := ObjectPool.new(); particles.warm(200)
	var removed := 0
	for frame in 36000: # 10 minutes at 60 Hz
		if frame % 90 == 0:
			for i in 40: terrain.request_damage(Vector2i((frame + i * 17) % 256, (frame / 3 + i * 31) % 256))
		removed += terrain.commit_damage(); terrain.physics_tick()
		if frame % 30 == 0:
			var particle := particles.acquire(); particles.release(particle)
	var ok := terrain.dirty_chunks.size() == 0 and particles.active.is_empty() and removed > 0
	print("ENDURANCE seconds=600 removed=%d rebuilds=%d pool_available=%d status=%s" % [removed, terrain.total_rebuilds, particles.available.size(), "pass" if ok else "fail"])
	quit(0 if ok else 1)
