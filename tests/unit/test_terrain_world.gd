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
