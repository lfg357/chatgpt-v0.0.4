extends "res://tests/test_case.gd"
const TerrainService = preload("res://src/gameplay/terrain_service.gd")
const ObjectPool = preload("res://src/gameplay/object_pool.gd")
const EffectPools = preload("res://src/gameplay/effect_pools.gd")

func test_tile_damage_is_deduplicated_per_frame() -> bool:
	var terrain := TerrainService.new(); terrain.setup(64, 64)
	terrain.request_damage(Vector2i(4, 4)); terrain.request_damage(Vector2i(4, 4))
	assert_equal(terrain.commit_damage(), 1)
	return true

func test_drill_damage_builds_cracks_before_tile_breaks() -> bool:
	var terrain := TerrainService.new(); terrain.setup(16, 16)
	var cell := Vector2i(4, 4)
	for _tick in range(TerrainService.TILE_DURABILITY - 1):
		terrain.request_damage(cell, 1)
		assert_equal(terrain.commit_damage(), 0)
	assert_true(terrain.is_solid(cell), "drill damage must show progress before removal")
	assert_true(terrain.damage_ratio(cell) > 0.9)
	terrain.request_damage(cell, 1)
	assert_equal(terrain.commit_damage(), 1)
	assert_true(not terrain.is_solid(cell), "tile breaks only after durability is exhausted")
	return true

func test_removed_tile_has_no_ghost_collision() -> bool:
	var terrain := TerrainService.new(); terrain.setup(64, 64)
	terrain.request_damage(Vector2i(4, 4)); terrain.commit_damage()
	assert_true(not terrain.has_collision(Vector2i(4, 4)))
	return true

func test_explosion_caps_changed_cells() -> bool:
	var terrain := TerrainService.new(); terrain.setup(64, 64)
	assert_true(terrain.request_explosion(Vector2i(32, 32), 20) <= TerrainService.MAX_EXPLOSION_CELLS)
	assert_equal(terrain.commit_damage(), TerrainService.MAX_EXPLOSION_CELLS)
	return true

func test_chunk_rebuild_budget() -> bool:
	var terrain := TerrainService.new(); terrain.setup(128, 128)
	for x in [1, 33, 65, 97]: terrain.request_damage(Vector2i(x, 1))
	terrain.commit_damage(); assert_equal(terrain.physics_tick(), 2); assert_equal(terrain.physics_tick(), 2)
	return true

func test_object_pool_recycles() -> bool:
	var pool := ObjectPool.new(); pool.warm(2)
	var item := pool.acquire(); pool.release(item)
	pool.release(item)
	assert_equal(pool.available.size(), 2); assert_equal(pool.active.size(), 0)
	return true

func test_all_effect_pools_recycle() -> bool:
	var pools := EffectPools.new()
	pools.warm_all(2)
	for kind in [&"debris", &"dust", &"sparks", &"damage_numbers"]:
		var item := pools.acquire(kind)
		pools.release(kind, item)
	assert_equal(pools.debris.active.size(), 0)
	assert_equal(pools.dust.active.size(), 0)
	assert_equal(pools.sparks.active.size(), 0)
	assert_equal(pools.damage_numbers.active.size(), 0)
	return true
