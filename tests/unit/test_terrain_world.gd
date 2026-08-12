extends "res://tests/test_case.gd"
const TerrainWorld = preload("res://src/gameplay/terrain_world.gd")

func test_dirty_chunk_disables_existing_collision_before_rebuild() -> bool:
	var world := TerrainWorld.new()
	world.grid_size = Vector2i(32, 32)
	world.terrain.setup(32, 32)
	world._rebuild_chunk_collision(Vector2i.ZERO)
	var body: StaticBody2D = world.chunk_bodies[Vector2i.ZERO]
	world.request_damage(Vector2i(1, 1))
	world.terrain.commit_damage()
	world._disable_dirty_chunk_collision()
	assert_equal(body.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true(not world.terrain.has_collision(Vector2i(1, 1)))
	world.free()
	return true

func test_chunk_collision_merges_horizontal_solid_runs() -> bool:
	var world := TerrainWorld.new()
	world.grid_size = Vector2i(32, 32)
	world.terrain.setup(32, 32)
	world._rebuild_chunk_collision(Vector2i.ZERO)
	var body: StaticBody2D = world.chunk_bodies[Vector2i.ZERO]
	assert_equal(body.get_child_count(), 32, "a full chunk should use one collision run per row")
	assert_true(body.get_child_count() < 1024, "collision rebuild must not allocate one node per tile")
	world.free()
	return true

func test_mineral_hardness_changes_production_drill_ticks() -> bool:
	var ticks := []
	for hardness in [1.0, 1.2, 1.8]:
		var world := TerrainWorld.new(); world.terrain.setup(4, 4); var cell := Vector2i(1, 1); world.drill_hardness[cell] = hardness
		var count := 0
		while world.terrain.is_solid(cell) and count < 100:
			world.request_damage(cell, 1); world.terrain.commit_damage(); count += 1
		ticks.append(count); world.free()
	assert_true(ticks[0] < ticks[1] and ticks[1] < ticks[2], "hardness drill ticks must increase: %s" % [ticks])
	return true
